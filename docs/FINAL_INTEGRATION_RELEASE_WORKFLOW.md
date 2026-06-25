# Final Integration / Release Workflow

## Recommended verification order

1. Start server.
2. Run `/rrcs_version`.
3. Run `/rrcs_selftest`.
4. Run `/rrcs_health`.
5. Run `/rrcs_packcheck`.
6. Run `/rrcs_uploadcheck` if upload bridge is enabled.
7. Run `/rrcs_aicheck` if AI is enabled.
8. Run `/rrcs_marketcheck` if marketplace is enabled.
9. Create a test design.
10. Save it.
11. Print it.
12. Use item from ox_inventory.
13. Ask another player to join and confirm sync.

## What OK looks like

- Menu opens.
- Design saves.
- Printed item appears.
- Metadata contains designId and preview/image URL or data URL.
- Item use applies component/drawable.
- `/rrcs_health` does not show FAIL.

## What still depends on your server assets

Real print visibility on actual GTA clothing requires valid streamed blank garment files.
