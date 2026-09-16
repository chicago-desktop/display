# Display module

Use the shared `../shell/docs/sdk.md` and `wippy-window-app` skill. Keep all
Display UI and animation code in this module. Do not add Display imports to
shell. Public UI, code and documentation are English. Run `make test` and
`make lint` with a Chicago runtime containing gfx; inspect test/shots PNGs.
Keep host resources in test/. Registry entries have one owner. Preserve other
agents' changes. New appearance extensions must use a documented registry API.
