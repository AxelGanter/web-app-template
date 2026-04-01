# AGENTS.md - AI Assistant Behavior Guide

> **Project-specific info:** See [PROJECT.md](PROJECT.md)  
> **Daily logs:** See [devlogs/](devlogs/)  


# AGENTS.md - AI Assistant Behavior

## 🔊 Audio Feedback
```bash
./audio2user.sh "Tests passed" # play BEFORE commit
```
## Todos: [TODO.md](TODO.md)

- after each human input: `manage_todo_list`
- TODO.md is your file where you manage your todos
- CHECKLIST.txt is a simple list that you can check off (don't add, only check off)

## 🎯 Fail Fast!
- NO fallbacks (if something is unreachable → Error)
- NO silent failures
- YAGNI (don't build unused features)

## 🔄 Workflow
- Re-read AGENTS.md (this file)
- Create todos 
- Change code
- `./stop.sh && ./start.sh`
- `./test.sh`
- `./audio2user.sh "Tests passed"`
- `git commit`
- update todos

## 📏 Code Quality
- Max 400 lines/file
- Type hints (Python 3.12)
- Async/await for I/O
- DRY, YAGNI


