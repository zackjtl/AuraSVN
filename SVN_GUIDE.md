# SVN Operation Guide
## Following SVN_PATH_RULE.md Rules

## Important Rules
1. **Must use correct svn.exe path**: `C:\Program Files\TortoiseSVN\bin\svn.exe`
2. **Must use specified parameters**: `--non-interactive --trust-server-cert-failures=unknown-ca,cn-mismatch,expired,not-yet-valid,other`
3. **Follow revision lookup rules**: Always use `svn log -v -r<N>` to find correct path
4. **Use peg revision for checkout**: `<url>@<revision>`
5. **Follow working copy naming**: `<ProjectName>_<BranchName or trunk>_<Timestamp>`

## Common Commands

### 1. Check working copy info
```bash
svn info
```

### 2. View recent revisions
```bash
svn log -l 10
```

### 3. View specific revision details
```bash
svn log -v -r<revision>
```

### 4. Check working copy status
```bash
svn status
```

### 5. Update working copy
```bash
svn update
```

### 6. View differences between revisions
```bash
svn diff -r<old>:<new>
```

### 7. List SVN directory contents
```bash
svn list <url>
```

## Workflow Example: Checkout specific revision

### Step 1: Find correct path for revision
```bash
svn log -v -r263 https://svn1.embestor.local/svn/ET1288_AP
```

### Step 2: Look for "Changed paths:" in output
Example output:
```
Changed paths:
  M /ET1288_AP/trunk/some/file.txt
```

### Step 3: Truncate path to /ET1288_AP or /ET1288_AP/trunk

### Step 4: Checkout with peg revision
```bash
svn checkout https://svn1.embestor.local/svn/ET1288_AP/trunk@263 ET1288_AP_trunk_20260330
```

## Practical Examples

### Example 1: Check ET1288_AP_BR3045 working copy
```bash
cd ET1288_AP_BR3045
"C:\Program Files\TortoiseSVN\bin\svn.exe" --non-interactive --trust-server-cert-failures=unknown-ca,cn-mismatch,expired,not-yet-valid,other info
cd ..
```

### Example 2: View last 3 revisions
```bash
cd ET1288_AP_BR3045
"C:\Program Files\TortoiseSVN\bin\svn.exe" --non-interactive --trust-server-cert-failures=unknown-ca,cn-mismatch,expired,not-yet-valid,other log -l 3
cd ..
```

### Example 3: Find path for revision 3045
```bash
"C:\Program Files\TortoiseSVN\bin\svn.exe" --non-interactive --trust-server-cert-failures=unknown-ca,cn-mismatch,expired,not-yet-valid,other log -v -r3045 https://svn1.embestor.local/svn/ET1288_AP
```

## Notes
- Always use the specified svn.exe path and parameters
- Handle Chinese paths with Windows encoding (cp950/Big5)
- Follow naming conventions for consistency
- Use peg revision to ensure correct checkout

## Ready-to-use Commands

Here are the exact commands you can copy and use:

1. **Check current working copy**:
   ```powershell
   cd ET1288_AP_BR3045
   & "C:\Program Files\TortoiseSVN\bin\svn.exe" --non-interactive --trust-server-cert-failures=unknown-ca,cn-mismatch,expired,not-yet-valid,other info
   ```

2. **View recent changes**:
   ```powershell
   cd ET1288_AP_BR3045
   & "C:\Program Files\TortoiseSVN\bin\svn.exe" --non-interactive --trust-server-cert-failures=unknown-ca,cn-mismatch,expired,not-yet-valid,other log -l 5
   ```

3. **Check status**:
   ```powershell
   cd ET1288_AP_BR3045
   & "C:\Program Files\TortoiseSVN\bin\svn.exe" --non-interactive --trust-server-cert-failures=unknown-ca,cn-mismatch,expired,not-yet-valid,other status
   ```

4. **Update working copy**:
   ```powershell
   cd ET1288_AP_BR3045
   & "C:\Program Files\TortoiseSVN\bin\svn.exe" --non-interactive --trust-server-cert-failures=unknown-ca,cn-mismatch,expired,not-yet-valid,other update
   ```