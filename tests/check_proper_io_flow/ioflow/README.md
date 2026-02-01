# IOFLOW Technical Documentation

## 1. Overview
`ioflow` is a C++23 utility designed to wrap an external process in a bi-directional pipe, logging a "conversation" between `STDIN` and a `FIFO` file. It groups inputs and outputs into logical transactions based on a **50ms reaction-time window**.

## 2. Program Logic Flow
The program operates as a state machine divided into two concurrent threads:

### A. The Main Thread (The Orchestrator)
1. **Solicitation Phase**: It waits for a line from `STDIN`.
2. **Transaction Start**: Upon receiving input, it checks if a transaction is already active. If not, it increments the transaction counter (#i) and prints the `=== IN #i ===` header.
3. **Propagation**: It logs the input line to `STDERR` and flushes it to `STDOUT` (sending it to the external program).
4. **The Reaction Window (50ms)**:
   - It waits up to 50ms for the background thread to signal that data has arrived from the FIFO.
   - **Case 1 (Activity)**: If data arrives, it prints the `--- OUT #i ---` header and resets the 50ms timer.
   - **Case 2 (Silence)**: If 50ms pass without output, it assumes the external program needs more data. It keeps the current `IN #i` block "open" and loops back to wait for more `STDIN`.

### B. The FIFO Thread (The Collector)
1. It opens the specified FIFO file and blocks until a writer (the external program) connects.
2. It continuously performs `getline` on the FIFO.
3. It uses a **Backpressure Mechanism**: It will not read the next line from the FIFO until the Main Thread has confirmed the previous line was logged.

---

## 3. Critical Technical Challenges & Solutions

### Deadlock: The Circular Pipe Dependency
*   **Problem**: In a bash pipeline like `... | ./ioflow fifo | cat > fifo`, the program `cat` is waiting for `ioflow` to finish, while `ioflow` is waiting for the FIFO to close. Since `cat` is the one writing to the FIFO, neither ever exits.
*   **Solution**: When `STDIN` reaches EOF, `ioflow` explicitly calls `close(STDOUT_FILENO)`. This sends an EOF to `cat`, causing it to exit and close the FIFO, which finally allows the `fifo_reader` thread to terminate.

### The SIGPIPE / Broken Pipe Crash
*   **Problem**: If the external program (`prog_rw`) terminates early (e.g., after reading only 1 of 3 lines), any subsequent write to `STDOUT` triggers a `SIGPIPE` signal, which kills `ioflow` by default. This causes `ioflow` to miss the remaining lines in `STDIN`.
*   **Solution**: By calling `std::signal(SIGPIPE, SIG_IGN)`, the program ignores the termination signal. Subsequent writes to `STDOUT` simply fail gracefully, allowing the main loop to continue reading and logging the rest of `STDIN` to `STDERR`.

### Transaction Grouping (Temporal Context)
*   **Problem**: How to determine if three rapid lines from `STDIN` belong to one transaction or three?
*   **Solution**: We introduced the `in_block_active` flag. 
    - It is set to `true` when an `IN` header is printed. 
    - It only resets to `false` when a line is received from the `OUT` (FIFO) side. 
    - If 50ms of silence occurs, we loop back to `STDIN` *without* resetting the flag, ensuring the next input is printed under the same header.

### The "Orphan" Response
*   **Problem**: If `STDIN` closes immediately after sending a message, but the external program takes 1 second to respond, a naive program would exit and lose the response.
*   **Solution**: We implemented a **Phase 2 Drain**. After the `STDIN` loop finishes, the program enters a secondary loop that waits indefinitely for the FIFO to close, ensuring late responses are captured and logged.

---

## 4. Known "Gotchas" & Limitations

### 1. SIGPIPE Signals
If the external writer crashes, writing to `STDOUT` will trigger a `SIGPIPE`. By default, this kills the program. 
*   *Status*: Handled via the "Drain" phase which ensures we don't close our end prematurely, but production environments should ideally use `signal(SIGPIPE, SIG_IGN)`.

### 2. Blocking FIFO Open
Opening an `std::ifstream` on a FIFO is a blocking operation.
*   *Status*: Handled by moving the constructor into the background thread. If the FIFO is never opened by a writer, the main thread will still function but the background thread will stay "parked" at the open call.

### 3. Buffer Bloat
Linux pipes have a 64KB buffer. If the external program produces 1MB of data instantly and the Main Thread is busy with a 50ms sleep, the external program will freeze.
*   *Status*: We mitigated this by ensuring the 50ms `wait_for` is immediately interrupted the moment data hits the FIFO, keeping the pipe as empty as possible.

### 4. Line Delimiters
The program is strictly line-oriented (`\n`). If the external program sends a stream of data without newlines, `std::getline` will block and the 50ms reaction timer will not accurately reflect the start of the data arrival.

---

## 5. Usage Requirements
- **C++ Standard**: C++23 (uses `<print>`, `<format>`, and `std::optional`).
- **OS**: Linux/Unix (required for FIFO and `close(STDOUT_FILENO)`).
- **Setup**: Must `mkfifo <name>` before execution.
