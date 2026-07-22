package apperror

import (
	"errors"
	"fmt"
	"net/http"
)

type Error struct {
	Code       string
	Message    string
	Status     int
	Details    map[string]any
	RetryAfter int
	cause      error
}

func (e *Error) Error() string {
	if e.cause == nil {
		return e.Code + ": " + e.Message
	}
	return fmt.Sprintf("%s: %s: %v", e.Code, e.Message, e.cause)
}

func (e *Error) Unwrap() error { return e.cause }

func New(status int, code, message string) *Error {
	return &Error{Code: code, Message: message, Status: status}
}

func Wrap(status int, code, message string, cause error) *Error {
	return &Error{Code: code, Message: message, Status: status, cause: cause}
}

func As(err error) *Error {
	var target *Error
	if errors.As(err, &target) {
		return target
	}
	return Wrap(http.StatusInternalServerError, "internal_error", "Something went wrong.", err)
}

var (
	ErrUnauthorized = New(http.StatusUnauthorized, "unauthorized", "Sign in to continue.")
	ErrForbidden    = New(http.StatusForbidden, "forbidden", "You do not have access to this resource.")
	ErrNotFound     = New(http.StatusNotFound, "not_found", "The requested resource was not found.")
	ErrConflict     = New(http.StatusConflict, "conflict", "The request conflicts with current state.")
	ErrValidation   = New(http.StatusUnprocessableEntity, "validation_error", "Check the request and try again.")
)
