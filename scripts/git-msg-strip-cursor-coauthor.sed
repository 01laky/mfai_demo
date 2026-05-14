# Used by: git filter-branch --msg-filter "sed -f .../git-msg-strip-cursor-coauthor.sed"
# and mirrored in .githooks/prepare-commit-msg (strip before commit).
/^Co-authored-by:[[:space:]]*Cursor/d
/^Co-authored-by:.*cursoragent@cursor\.com/d
/^Co-authored-by:.*@cursor\.com/d
/^Co-authored-by:.*[Aa]nysphere/d
/^Signed-off-by:.*[Cc]ursor/d
/^Signed-off-by:.*cursoragent/d
