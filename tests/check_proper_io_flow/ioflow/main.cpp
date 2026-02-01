#include <iostream>
#include <fstream>
#include <string>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <optional>
#include <print>     // C++23 for std::println
#include <chrono>
#include <unistd.h>  // For STDOUT_FILENO and close()
#include <format>    // For std::format
#include <csignal>

using namespace std::chrono_literals;

// Synchronized state for inter-thread communication
struct SharedState {
    std::mutex mtx;
    std::condition_variable cv_new_line;  // Notifies main thread of data from FIFO
    std::condition_variable cv_next_read; // Notifies FIFO thread that data was consumed
    std::optional<std::string> fifo_line; // Holds the current line from prog_rw
    std::atomic<bool> running{true};     // Tracks if the FIFO is still open
};

/**
 * Background thread worker: Reads from the FIFO as fast as the main thread consumes.
 */
void fifo_reader_worker(const std::string path, SharedState& state) {
    std::ifstream fifo(path);
    if (!fifo.is_open()) {
        state.running = false;
        state.cv_new_line.notify_all();
        return;
    }

    std::string line;
    while (state.running) {
        {
            // Flow Control: Don't read a new line until the previous one is logged
            std::unique_lock lock(state.mtx);
            state.cv_next_read.wait(lock, [&] { 
                return !state.fifo_line.has_value() || !state.running; 
            });
        }
        if (!state.running) break;

        if (std::getline(fifo, line)) {
            std::lock_guard lock(state.mtx);
            state.fifo_line = line;
            state.cv_new_line.notify_all();
        } else {
            state.running = false; // FIFO closed by writer (prog_rw)
            state.cv_new_line.notify_all();
            break;
        }
    }
}

int main(int argc, char* argv[]) {
    std::signal(SIGPIPE, SIG_IGN); // Ignore SIGPIPE so that we keep reading lines from STDIN..
                                   // ..even after prog_rw terminates

    if (argc < 2) {
        std::println(std::cerr, "Usage: {} <fifo_path>", argv[0]);
        return 1;
    }

    SharedState state;
    std::thread fifoThread(fifo_reader_worker, argv[1], std::ref(state));

    std::string cin_line;
    uint64_t transaction_idx = 0;
    uint64_t last_out_header_idx = 0;
    bool in_block_active = false;

    // PHASE 1: Process STDIN while available
    while (std::getline(std::cin, cin_line)) {
        // Group inputs if no response was received within 50ms (Logical Transaction)
        if (!in_block_active) {
            std::println(std::cerr, "{:=^{}}", 
                         std::format("=== IN  #{} ===", ++transaction_idx), 80);
            in_block_active = true;
        }

        std::println(std::cerr, "{}", cin_line);
        std::println(std::cout, "{}", cin_line); // Push to pipe
        std::cout.flush(); // Ensure prog_rw receives data immediately

        // Inner Loop: Wait for response from prog_rw
        while (state.running) {
            std::unique_lock lock(state.mtx);
            
            // The "Reaction Time": Wait 50ms for a response
            bool notified = state.cv_new_line.wait_for(lock, 50ms, [&] { 
                return state.fifo_line.has_value() || !state.running; 
            });

            if (!notified) {
                // Silence for 50ms: Keep transaction active and get more input
                break; 
            }

            if (state.fifo_line) {
                // Header prints once per logical transaction's output sequence
                if (last_out_header_idx != transaction_idx) {
                    std::println(std::cerr, "{:-^{}}", 
                                 std::format("--- OUT #{} ---", transaction_idx), 80);
                    last_out_header_idx = transaction_idx;
                }

                std::println(std::cerr, "{}", *state.fifo_line);
                state.fifo_line.reset();
                state.cv_next_read.notify_all();
                
                // An output occurred: Transaction is considered complete
                in_block_active = false; 
            }
            if (!state.running) break;
        }
    }

    // PHASE 2: Drain Orphans
    // STDIN is closed. Notify prog_rw that no more data is coming.
    close(STDOUT_FILENO);

    while (state.running) {
        std::unique_lock lock(state.mtx);
        state.cv_new_line.wait(lock, [&] { return state.fifo_line.has_value() || !state.running; });

        if (state.fifo_line) {
            if (last_out_header_idx != transaction_idx) {
                std::println(std::cerr, "{:-^{}}", 
                             std::format("--- OUT #{} ---", transaction_idx), 80);
                last_out_header_idx = transaction_idx;
            }
            std::println(std::cerr, "{}", *state.fifo_line);
            state.fifo_line.reset();
            state.cv_next_read.notify_all();
        }
    }

    if (fifoThread.joinable()) fifoThread.join();
    return 0;
}
