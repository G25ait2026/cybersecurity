# CVE-2016-5195: Dirty COW Hands-on Docker Lab

This lab provides an end-to-end environment to demonstrate and analyze the **Dirty COW (Copy-On-Write)** vulnerability within a Docker container.

## 1. Vulnerability Background
Dirty COW (CVE-2016-5195) is a highly critical kernel-level race condition vulnerability discovered in the Linux kernel's memory management subsystem.
- **Vulnerability Type**: Race Condition / Privilege Escalation.
- **Affected Kernel Range**: Linux kernels from 2.6.22 (2007) up to 4.8.3 / 4.7.9 / 4.4.26 (October 2016).
- **Subsystem**: Memory Management (`mm/gup.c` - Get User Pages).
- **Core Cause**: The page-fault handler implementation could lead to a race condition when breaking Copy-on-Write (COW) page tables via concurrent system calls `madvise(MADV_DONTNEED)` and writes via `/proc/self/mem`.

---

## 2. The Docker Isolation Context
Docker containers share the host's operating system kernel.
- **The Kernel Sharing Paradox**: Although Docker isolates filesystems, process trees, and network interfaces using namespaces and cgroups, **it does not isolate or virtualize the kernel**.
- **Exploitation Impact**: If the host kernel is vulnerable (e.g. pre-October 2016 kernels), an unprivileged user inside a Docker container can exploit Dirty COW to write to files that are marked read-only within the container, or even corrupt host-level files, leading to a container escape or full privilege escalation.
- **Mitigation on Modern Systems**: On a modern host, the kernel handles Copy-on-Write page table checks atomicly, which prevents the race condition. The exploit will run but the file will remain unmodified.

---

## 3. Lab Contents
- `Dockerfile`: Configures a secure, non-root user `victim` and creates a root-owned, read-only secret target file `/var/secret/target.txt`.
- `dirtyc0w.c`: The core C implementation of the race condition exploit utilizing `mmap()`, `madvise()`, and `procfs` virtual memory access.
- `run_demo.sh`: The container orchestrator that runs diagnostic information, compiles `dirtyc0w.c`, executes the exploit, and verifies the outcome.

---

## 4. How to Run the Lab

Ensure you have Docker running on your host system, then execute the following commands in your shell:

### Step 1: Build the Container
```powershell
docker build -t dirtycow-lab .
```

### Step 2: Run the Demonstration Container
```powershell
docker run --rm -it dirtycow-lab
```

CI and local checks
-------------------

This repository includes a GitHub Actions workflow at `.github/workflows/ci.yml` that runs static checks on push/PR to `main`:

- Python: `black --check` and `flake8` on `generate_presentation.py` (workflow fails on issues)
- Shell: `shellcheck` on `run_demo.sh`
- Dockerfile: `hadolint` on `Dockerfile`
- C static analysis: `cppcheck` on `dirtyc0w.c` (analysis only; the workflow does NOT compile or run exploit code)

Run the same checks locally:

```bash
python -m pip install --upgrade pip
python -m pip install flake8 black
black --check generate_presentation.py
flake8 generate_presentation.py
sudo apt-get update && sudo apt-get install -y shellcheck cppcheck
shellcheck run_demo.sh
cppcheck --enable=warning,style dirtyc0w.c
```

If you'd like, I can auto-format `generate_presentation.py` with `black` and apply fixes for the linter warnings in a follow-up change.

---

## 5. Under-the-Hood Exploit Flow

1. **Memory Mapping**: The C exploit opens the target file in read-only mode and maps it into its virtual address space as a private copy-on-write mapping using:
   ```c
   map = mmap(NULL, st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
   ```
2. **The Discard Thread**: A thread continuously loops, calling:
   ```c
   madvise(map, 100, MADV_DONTNEED);
   ```
   This signals to the kernel that the physical page holding the mapped file content is no longer needed, forcing the kernel to fetch it from disk on the next write attempt.
3. **The Write Thread**: Concurrently, another thread opens the virtual file representing its own process's memory space (`/proc/self/mem`) and writes to the memory range of the mapped file:
   ```c
   lseek(f, map, SEEK_SET);
   write(f, payload, len);
   ```
4. **The Race Condition**:
   - The kernel starts handling the write. It determines that the target page is read-only and initiates a COW (Copy-On-Write) operation to copy the page content into private memory before writing.
   - During the COW process, before the new private page table mapping is finalized, the **Discard Thread** calls `madvise(MADV_DONTNEED)`. This instructs the kernel to throw away the newly allocated page.
   - Due to the race condition, the write thread completes its operation. Instead of writing to a new private copied page, the write is written directly to the **original, global read-only page cache**, modifying the actual file on disk.
