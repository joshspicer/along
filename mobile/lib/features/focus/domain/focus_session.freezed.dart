// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'focus_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionParticipant {

 String get accountId; String get displayName; DateTime get joinedAt;
/// Create a copy of SessionParticipant
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionParticipantCopyWith<SessionParticipant> get copyWith => _$SessionParticipantCopyWithImpl<SessionParticipant>(this as SessionParticipant, _$identity);

  /// Serializes this SessionParticipant to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionParticipant&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accountId,displayName,joinedAt);

@override
String toString() {
  return 'SessionParticipant(accountId: $accountId, displayName: $displayName, joinedAt: $joinedAt)';
}


}

/// @nodoc
abstract mixin class $SessionParticipantCopyWith<$Res>  {
  factory $SessionParticipantCopyWith(SessionParticipant value, $Res Function(SessionParticipant) _then) = _$SessionParticipantCopyWithImpl;
@useResult
$Res call({
 String accountId, String displayName, DateTime joinedAt
});




}
/// @nodoc
class _$SessionParticipantCopyWithImpl<$Res>
    implements $SessionParticipantCopyWith<$Res> {
  _$SessionParticipantCopyWithImpl(this._self, this._then);

  final SessionParticipant _self;
  final $Res Function(SessionParticipant) _then;

/// Create a copy of SessionParticipant
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accountId = null,Object? displayName = null,Object? joinedAt = null,}) {
  return _then(_self.copyWith(
accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionParticipant].
extension SessionParticipantPatterns on SessionParticipant {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionParticipant value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionParticipant() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionParticipant value)  $default,){
final _that = this;
switch (_that) {
case _SessionParticipant():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionParticipant value)?  $default,){
final _that = this;
switch (_that) {
case _SessionParticipant() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String accountId,  String displayName,  DateTime joinedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionParticipant() when $default != null:
return $default(_that.accountId,_that.displayName,_that.joinedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String accountId,  String displayName,  DateTime joinedAt)  $default,) {final _that = this;
switch (_that) {
case _SessionParticipant():
return $default(_that.accountId,_that.displayName,_that.joinedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String accountId,  String displayName,  DateTime joinedAt)?  $default,) {final _that = this;
switch (_that) {
case _SessionParticipant() when $default != null:
return $default(_that.accountId,_that.displayName,_that.joinedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SessionParticipant implements SessionParticipant {
  const _SessionParticipant({required this.accountId, required this.displayName, required this.joinedAt});
  factory _SessionParticipant.fromJson(Map<String, dynamic> json) => _$SessionParticipantFromJson(json);

@override final  String accountId;
@override final  String displayName;
@override final  DateTime joinedAt;

/// Create a copy of SessionParticipant
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionParticipantCopyWith<_SessionParticipant> get copyWith => __$SessionParticipantCopyWithImpl<_SessionParticipant>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionParticipantToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionParticipant&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accountId,displayName,joinedAt);

@override
String toString() {
  return 'SessionParticipant(accountId: $accountId, displayName: $displayName, joinedAt: $joinedAt)';
}


}

/// @nodoc
abstract mixin class _$SessionParticipantCopyWith<$Res> implements $SessionParticipantCopyWith<$Res> {
  factory _$SessionParticipantCopyWith(_SessionParticipant value, $Res Function(_SessionParticipant) _then) = __$SessionParticipantCopyWithImpl;
@override @useResult
$Res call({
 String accountId, String displayName, DateTime joinedAt
});




}
/// @nodoc
class __$SessionParticipantCopyWithImpl<$Res>
    implements _$SessionParticipantCopyWith<$Res> {
  __$SessionParticipantCopyWithImpl(this._self, this._then);

  final _SessionParticipant _self;
  final $Res Function(_SessionParticipant) _then;

/// Create a copy of SessionParticipant
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accountId = null,Object? displayName = null,Object? joinedAt = null,}) {
  return _then(_SessionParticipant(
accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$FocusNote {

 String get id; String get accountId; String get displayName; String get body; DateTime get createdAt;
/// Create a copy of FocusNote
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FocusNoteCopyWith<FocusNote> get copyWith => _$FocusNoteCopyWithImpl<FocusNote>(this as FocusNote, _$identity);

  /// Serializes this FocusNote to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FocusNote&&(identical(other.id, id) || other.id == id)&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.body, body) || other.body == body)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,accountId,displayName,body,createdAt);

@override
String toString() {
  return 'FocusNote(id: $id, accountId: $accountId, displayName: $displayName, body: $body, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $FocusNoteCopyWith<$Res>  {
  factory $FocusNoteCopyWith(FocusNote value, $Res Function(FocusNote) _then) = _$FocusNoteCopyWithImpl;
@useResult
$Res call({
 String id, String accountId, String displayName, String body, DateTime createdAt
});




}
/// @nodoc
class _$FocusNoteCopyWithImpl<$Res>
    implements $FocusNoteCopyWith<$Res> {
  _$FocusNoteCopyWithImpl(this._self, this._then);

  final FocusNote _self;
  final $Res Function(FocusNote) _then;

/// Create a copy of FocusNote
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? accountId = null,Object? displayName = null,Object? body = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [FocusNote].
extension FocusNotePatterns on FocusNote {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FocusNote value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FocusNote() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FocusNote value)  $default,){
final _that = this;
switch (_that) {
case _FocusNote():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FocusNote value)?  $default,){
final _that = this;
switch (_that) {
case _FocusNote() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String accountId,  String displayName,  String body,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FocusNote() when $default != null:
return $default(_that.id,_that.accountId,_that.displayName,_that.body,_that.createdAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String accountId,  String displayName,  String body,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _FocusNote():
return $default(_that.id,_that.accountId,_that.displayName,_that.body,_that.createdAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String accountId,  String displayName,  String body,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _FocusNote() when $default != null:
return $default(_that.id,_that.accountId,_that.displayName,_that.body,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FocusNote implements FocusNote {
  const _FocusNote({required this.id, required this.accountId, required this.displayName, required this.body, required this.createdAt});
  factory _FocusNote.fromJson(Map<String, dynamic> json) => _$FocusNoteFromJson(json);

@override final  String id;
@override final  String accountId;
@override final  String displayName;
@override final  String body;
@override final  DateTime createdAt;

/// Create a copy of FocusNote
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FocusNoteCopyWith<_FocusNote> get copyWith => __$FocusNoteCopyWithImpl<_FocusNote>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FocusNoteToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FocusNote&&(identical(other.id, id) || other.id == id)&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.body, body) || other.body == body)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,accountId,displayName,body,createdAt);

@override
String toString() {
  return 'FocusNote(id: $id, accountId: $accountId, displayName: $displayName, body: $body, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$FocusNoteCopyWith<$Res> implements $FocusNoteCopyWith<$Res> {
  factory _$FocusNoteCopyWith(_FocusNote value, $Res Function(_FocusNote) _then) = __$FocusNoteCopyWithImpl;
@override @useResult
$Res call({
 String id, String accountId, String displayName, String body, DateTime createdAt
});




}
/// @nodoc
class __$FocusNoteCopyWithImpl<$Res>
    implements _$FocusNoteCopyWith<$Res> {
  __$FocusNoteCopyWithImpl(this._self, this._then);

  final _FocusNote _self;
  final $Res Function(_FocusNote) _then;

/// Create a copy of FocusNote
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? accountId = null,Object? displayName = null,Object? body = null,Object? createdAt = null,}) {
  return _then(_FocusNote(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$FocusSession {

 String get id; String get pairId; String get startedBy; SessionState get state; int get durationSeconds; DateTime get startedAt; DateTime get endsAt; int get version; bool get offlineOrigin; SessionState? get pauseOrigin; DateTime? get pausedAt; DateTime? get completedAt; DateTime? get cancelledAt; List<SessionParticipant> get participants; List<FocusNote> get notes;
/// Create a copy of FocusSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FocusSessionCopyWith<FocusSession> get copyWith => _$FocusSessionCopyWithImpl<FocusSession>(this as FocusSession, _$identity);

  /// Serializes this FocusSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FocusSession&&(identical(other.id, id) || other.id == id)&&(identical(other.pairId, pairId) || other.pairId == pairId)&&(identical(other.startedBy, startedBy) || other.startedBy == startedBy)&&(identical(other.state, state) || other.state == state)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.version, version) || other.version == version)&&(identical(other.offlineOrigin, offlineOrigin) || other.offlineOrigin == offlineOrigin)&&(identical(other.pauseOrigin, pauseOrigin) || other.pauseOrigin == pauseOrigin)&&(identical(other.pausedAt, pausedAt) || other.pausedAt == pausedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.cancelledAt, cancelledAt) || other.cancelledAt == cancelledAt)&&const DeepCollectionEquality().equals(other.participants, participants)&&const DeepCollectionEquality().equals(other.notes, notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,pairId,startedBy,state,durationSeconds,startedAt,endsAt,version,offlineOrigin,pauseOrigin,pausedAt,completedAt,cancelledAt,const DeepCollectionEquality().hash(participants),const DeepCollectionEquality().hash(notes));

@override
String toString() {
  return 'FocusSession(id: $id, pairId: $pairId, startedBy: $startedBy, state: $state, durationSeconds: $durationSeconds, startedAt: $startedAt, endsAt: $endsAt, version: $version, offlineOrigin: $offlineOrigin, pauseOrigin: $pauseOrigin, pausedAt: $pausedAt, completedAt: $completedAt, cancelledAt: $cancelledAt, participants: $participants, notes: $notes)';
}


}

/// @nodoc
abstract mixin class $FocusSessionCopyWith<$Res>  {
  factory $FocusSessionCopyWith(FocusSession value, $Res Function(FocusSession) _then) = _$FocusSessionCopyWithImpl;
@useResult
$Res call({
 String id, String pairId, String startedBy, SessionState state, int durationSeconds, DateTime startedAt, DateTime endsAt, int version, bool offlineOrigin, SessionState? pauseOrigin, DateTime? pausedAt, DateTime? completedAt, DateTime? cancelledAt, List<SessionParticipant> participants, List<FocusNote> notes
});




}
/// @nodoc
class _$FocusSessionCopyWithImpl<$Res>
    implements $FocusSessionCopyWith<$Res> {
  _$FocusSessionCopyWithImpl(this._self, this._then);

  final FocusSession _self;
  final $Res Function(FocusSession) _then;

/// Create a copy of FocusSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? pairId = null,Object? startedBy = null,Object? state = null,Object? durationSeconds = null,Object? startedAt = null,Object? endsAt = null,Object? version = null,Object? offlineOrigin = null,Object? pauseOrigin = freezed,Object? pausedAt = freezed,Object? completedAt = freezed,Object? cancelledAt = freezed,Object? participants = null,Object? notes = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,pairId: null == pairId ? _self.pairId : pairId // ignore: cast_nullable_to_non_nullable
as String,startedBy: null == startedBy ? _self.startedBy : startedBy // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as SessionState,durationSeconds: null == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,offlineOrigin: null == offlineOrigin ? _self.offlineOrigin : offlineOrigin // ignore: cast_nullable_to_non_nullable
as bool,pauseOrigin: freezed == pauseOrigin ? _self.pauseOrigin : pauseOrigin // ignore: cast_nullable_to_non_nullable
as SessionState?,pausedAt: freezed == pausedAt ? _self.pausedAt : pausedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelledAt: freezed == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,participants: null == participants ? _self.participants : participants // ignore: cast_nullable_to_non_nullable
as List<SessionParticipant>,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as List<FocusNote>,
  ));
}

}


/// Adds pattern-matching-related methods to [FocusSession].
extension FocusSessionPatterns on FocusSession {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FocusSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FocusSession() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FocusSession value)  $default,){
final _that = this;
switch (_that) {
case _FocusSession():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FocusSession value)?  $default,){
final _that = this;
switch (_that) {
case _FocusSession() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String pairId,  String startedBy,  SessionState state,  int durationSeconds,  DateTime startedAt,  DateTime endsAt,  int version,  bool offlineOrigin,  SessionState? pauseOrigin,  DateTime? pausedAt,  DateTime? completedAt,  DateTime? cancelledAt,  List<SessionParticipant> participants,  List<FocusNote> notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FocusSession() when $default != null:
return $default(_that.id,_that.pairId,_that.startedBy,_that.state,_that.durationSeconds,_that.startedAt,_that.endsAt,_that.version,_that.offlineOrigin,_that.pauseOrigin,_that.pausedAt,_that.completedAt,_that.cancelledAt,_that.participants,_that.notes);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String pairId,  String startedBy,  SessionState state,  int durationSeconds,  DateTime startedAt,  DateTime endsAt,  int version,  bool offlineOrigin,  SessionState? pauseOrigin,  DateTime? pausedAt,  DateTime? completedAt,  DateTime? cancelledAt,  List<SessionParticipant> participants,  List<FocusNote> notes)  $default,) {final _that = this;
switch (_that) {
case _FocusSession():
return $default(_that.id,_that.pairId,_that.startedBy,_that.state,_that.durationSeconds,_that.startedAt,_that.endsAt,_that.version,_that.offlineOrigin,_that.pauseOrigin,_that.pausedAt,_that.completedAt,_that.cancelledAt,_that.participants,_that.notes);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String pairId,  String startedBy,  SessionState state,  int durationSeconds,  DateTime startedAt,  DateTime endsAt,  int version,  bool offlineOrigin,  SessionState? pauseOrigin,  DateTime? pausedAt,  DateTime? completedAt,  DateTime? cancelledAt,  List<SessionParticipant> participants,  List<FocusNote> notes)?  $default,) {final _that = this;
switch (_that) {
case _FocusSession() when $default != null:
return $default(_that.id,_that.pairId,_that.startedBy,_that.state,_that.durationSeconds,_that.startedAt,_that.endsAt,_that.version,_that.offlineOrigin,_that.pauseOrigin,_that.pausedAt,_that.completedAt,_that.cancelledAt,_that.participants,_that.notes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FocusSession extends FocusSession {
  const _FocusSession({required this.id, required this.pairId, required this.startedBy, required this.state, required this.durationSeconds, required this.startedAt, required this.endsAt, required this.version, this.offlineOrigin = false, this.pauseOrigin, this.pausedAt, this.completedAt, this.cancelledAt, final  List<SessionParticipant> participants = const <SessionParticipant>[], final  List<FocusNote> notes = const <FocusNote>[]}): _participants = participants,_notes = notes,super._();
  factory _FocusSession.fromJson(Map<String, dynamic> json) => _$FocusSessionFromJson(json);

@override final  String id;
@override final  String pairId;
@override final  String startedBy;
@override final  SessionState state;
@override final  int durationSeconds;
@override final  DateTime startedAt;
@override final  DateTime endsAt;
@override final  int version;
@override@JsonKey() final  bool offlineOrigin;
@override final  SessionState? pauseOrigin;
@override final  DateTime? pausedAt;
@override final  DateTime? completedAt;
@override final  DateTime? cancelledAt;
 final  List<SessionParticipant> _participants;
@override@JsonKey() List<SessionParticipant> get participants {
  if (_participants is EqualUnmodifiableListView) return _participants;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_participants);
}

 final  List<FocusNote> _notes;
@override@JsonKey() List<FocusNote> get notes {
  if (_notes is EqualUnmodifiableListView) return _notes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_notes);
}


/// Create a copy of FocusSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FocusSessionCopyWith<_FocusSession> get copyWith => __$FocusSessionCopyWithImpl<_FocusSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FocusSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FocusSession&&(identical(other.id, id) || other.id == id)&&(identical(other.pairId, pairId) || other.pairId == pairId)&&(identical(other.startedBy, startedBy) || other.startedBy == startedBy)&&(identical(other.state, state) || other.state == state)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.version, version) || other.version == version)&&(identical(other.offlineOrigin, offlineOrigin) || other.offlineOrigin == offlineOrigin)&&(identical(other.pauseOrigin, pauseOrigin) || other.pauseOrigin == pauseOrigin)&&(identical(other.pausedAt, pausedAt) || other.pausedAt == pausedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.cancelledAt, cancelledAt) || other.cancelledAt == cancelledAt)&&const DeepCollectionEquality().equals(other._participants, _participants)&&const DeepCollectionEquality().equals(other._notes, _notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,pairId,startedBy,state,durationSeconds,startedAt,endsAt,version,offlineOrigin,pauseOrigin,pausedAt,completedAt,cancelledAt,const DeepCollectionEquality().hash(_participants),const DeepCollectionEquality().hash(_notes));

@override
String toString() {
  return 'FocusSession(id: $id, pairId: $pairId, startedBy: $startedBy, state: $state, durationSeconds: $durationSeconds, startedAt: $startedAt, endsAt: $endsAt, version: $version, offlineOrigin: $offlineOrigin, pauseOrigin: $pauseOrigin, pausedAt: $pausedAt, completedAt: $completedAt, cancelledAt: $cancelledAt, participants: $participants, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$FocusSessionCopyWith<$Res> implements $FocusSessionCopyWith<$Res> {
  factory _$FocusSessionCopyWith(_FocusSession value, $Res Function(_FocusSession) _then) = __$FocusSessionCopyWithImpl;
@override @useResult
$Res call({
 String id, String pairId, String startedBy, SessionState state, int durationSeconds, DateTime startedAt, DateTime endsAt, int version, bool offlineOrigin, SessionState? pauseOrigin, DateTime? pausedAt, DateTime? completedAt, DateTime? cancelledAt, List<SessionParticipant> participants, List<FocusNote> notes
});




}
/// @nodoc
class __$FocusSessionCopyWithImpl<$Res>
    implements _$FocusSessionCopyWith<$Res> {
  __$FocusSessionCopyWithImpl(this._self, this._then);

  final _FocusSession _self;
  final $Res Function(_FocusSession) _then;

/// Create a copy of FocusSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? pairId = null,Object? startedBy = null,Object? state = null,Object? durationSeconds = null,Object? startedAt = null,Object? endsAt = null,Object? version = null,Object? offlineOrigin = null,Object? pauseOrigin = freezed,Object? pausedAt = freezed,Object? completedAt = freezed,Object? cancelledAt = freezed,Object? participants = null,Object? notes = null,}) {
  return _then(_FocusSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,pairId: null == pairId ? _self.pairId : pairId // ignore: cast_nullable_to_non_nullable
as String,startedBy: null == startedBy ? _self.startedBy : startedBy // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as SessionState,durationSeconds: null == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,offlineOrigin: null == offlineOrigin ? _self.offlineOrigin : offlineOrigin // ignore: cast_nullable_to_non_nullable
as bool,pauseOrigin: freezed == pauseOrigin ? _self.pauseOrigin : pauseOrigin // ignore: cast_nullable_to_non_nullable
as SessionState?,pausedAt: freezed == pausedAt ? _self.pausedAt : pausedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelledAt: freezed == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,participants: null == participants ? _self._participants : participants // ignore: cast_nullable_to_non_nullable
as List<SessionParticipant>,notes: null == notes ? _self._notes : notes // ignore: cast_nullable_to_non_nullable
as List<FocusNote>,
  ));
}


}

// dart format on
