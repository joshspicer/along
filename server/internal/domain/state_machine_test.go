package domain

import "testing"

func TestSessionStateMachine(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name       string
		current    SessionState
		origin     *SessionState
		action     SessionAction
		want       SessionState
		wantOrigin *SessionState
		wantError  bool
	}{
		{name: "partner joins open room", current: SessionOpen, action: ActionJoin, want: SessionTogether},
		{name: "open room pauses", current: SessionOpen, action: ActionPause, want: SessionPaused, wantOrigin: state(SessionOpen)},
		{name: "together room pauses", current: SessionTogether, action: ActionPause, want: SessionPaused, wantOrigin: state(SessionTogether)},
		{name: "solo room resumes", current: SessionPaused, origin: state(SessionOpen), action: ActionResume, want: SessionOpen},
		{name: "shared room resumes", current: SessionPaused, origin: state(SessionTogether), action: ActionResume, want: SessionTogether},
		{name: "open completes", current: SessionOpen, action: ActionComplete, want: SessionCompleted},
		{name: "together completes", current: SessionTogether, action: ActionComplete, want: SessionCompleted},
		{name: "paused completes", current: SessionPaused, origin: state(SessionTogether), action: ActionComplete, want: SessionCompleted},
		{name: "active cancels", current: SessionOpen, action: ActionCancel, want: SessionCancelled},
		{name: "active expires", current: SessionTogether, action: ActionExpire, want: SessionExpired},
		{name: "cannot join together", current: SessionTogether, action: ActionJoin, wantError: true},
		{name: "cannot resume without origin", current: SessionPaused, action: ActionResume, wantError: true},
		{name: "terminal is immutable", current: SessionCompleted, action: ActionPause, wantError: true},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got, origin, err := NextState(test.current, test.origin, test.action)
			if test.wantError {
				if err == nil {
					t.Fatal("expected transition error")
				}
				return
			}
			if err != nil {
				t.Fatalf("NextState returned error: %v", err)
			}
			if got != test.want {
				t.Fatalf("state = %q, want %q", got, test.want)
			}
			if !sameState(origin, test.wantOrigin) {
				t.Fatalf("pause origin = %v, want %v", origin, test.wantOrigin)
			}
		})
	}
}

func TestTerminalStates(t *testing.T) {
	t.Parallel()
	for _, item := range []struct {
		state SessionState
		want  bool
	}{
		{SessionOpen, false},
		{SessionTogether, false},
		{SessionPaused, false},
		{SessionCompleted, true},
		{SessionCancelled, true},
		{SessionExpired, true},
	} {
		if got := item.state.Terminal(); got != item.want {
			t.Errorf("%s.Terminal() = %v, want %v", item.state, got, item.want)
		}
	}
}

func state(value SessionState) *SessionState { return &value }

func sameState(left, right *SessionState) bool {
	if left == nil || right == nil {
		return left == right
	}
	return *left == *right
}
