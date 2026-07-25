# Quick Verify

Superseded by the `/quick-site` skill — see
[`.claude/skills/quick-site/SKILL.md`](../.claude/skills/quick-site/SKILL.md)
for the full workflow (classify → implement → verify → repair → done/escalate).

The deterministic primitives the skill calls:
```
scripts/run.sh quick --baseline --risk <low|medium|high>
scripts/run.sh quick --verify   --risk <low|medium|high>
scripts/run.sh quick --suggest-risk   # advisory only
```
These are not meant to be run by hand day-to-day — use `/quick-site <request>`.
