Infos zum Projekt in PROJECT.md
 


# AGENTS.md - AI Assistant Behavior

## 🔊 Audio Feedback
```bash
./audio2user.sh "Tests bestanden" # play BEFORE commit
```
## Todos: [TODO.md](TODO.md)

- nach jedem Human-Input: `manage_todo_list`

## 🎯 Fail Fast!
- NO fallbacks (Core unreachable → Error)
- NO silent failures
- YAGNI (don't build unused features)

## 🔄 Workflow
- AGENTS.md nochmal lesen (this file)
- Todos anlegen 
- Code ändern
- `./stop.sh && ./start.sh`
- `./test.sh`
- `./audio2user.sh "Tests bestanden"`
- `git commit`
- todos updaten

## 📏 Code Quality
- Max 400 lines/file
- Type hints (Python 3.12)
- Async/await for I/O
- DRY, YAGNI


