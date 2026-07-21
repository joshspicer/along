package domain

import "fmt"

type SessionAction string

const (
	ActionJoin     SessionAction = "join"
	ActionPause    SessionAction = "pause"
	ActionResume   SessionAction = "resume"
	ActionComplete SessionAction = "complete"
	ActionCancel   SessionAction = "cancel"
	ActionExpire   SessionAction = "expire"
)

func NextState(current SessionState, pauseOrigin *SessionState, action SessionAction) (SessionState, *SessionState, error) {
	switch action {
	case ActionJoin:
		if current != SessionOpen {
			return "", nil, invalidTransition(current, action)
		}
		return SessionTogether, nil, nil
	case ActionPause:
		if current != SessionOpen && current != SessionTogether {
			return "", nil, invalidTransition(current, action)
		}
		origin := current
		return SessionPaused, &origin, nil
	case ActionResume:
		if current != SessionPaused || pauseOrigin == nil {
			return "", nil, invalidTransition(current, action)
		}
		if *pauseOrigin != SessionOpen && *pauseOrigin != SessionTogether {
			return "", nil, invalidTransition(current, action)
		}
		return *pauseOrigin, nil, nil
	case ActionComplete:
		if current == SessionOpen || current == SessionTogether || current == SessionPaused {
			return SessionCompleted, nil, nil
		}
	case ActionCancel:
		if current == SessionOpen || current == SessionTogether || current == SessionPaused {
			return SessionCancelled, nil, nil
		}
	case ActionExpire:
		if current == SessionOpen || current == SessionTogether || current == SessionPaused {
			return SessionExpired, nil, nil
		}
	}
	return "", nil, invalidTransition(current, action)
}

func invalidTransition(current SessionState, action SessionAction) error {
	return fmt.Errorf("cannot %s a %s session", action, current)
}
