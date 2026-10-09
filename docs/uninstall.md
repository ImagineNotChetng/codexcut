# Uninstall

codexcut installs nothing into Codex. It writes no settings, patches no binary
and touches no file under `~/.codex`.

```bash
# 1. remove the symlink
rm ~/.local/bin/codexcut

# 2. remove the checkout
rm -rf ~/projects/codexcut

# 3. remove optional config, if you created one
rm -rf ~/.config/codexcut
```

`codex` behaves as it did before, because it was never modified.

## Benchmark leftovers

`bench/results/` is gitignored and lives inside the checkout, so step 2 takes
it with everything else. Bench runs are ephemeral, so they leave no sessions in
`~/.codex`.
