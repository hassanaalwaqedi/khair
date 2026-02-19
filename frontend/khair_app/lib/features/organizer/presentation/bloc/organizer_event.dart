part of 'organizer_bloc.dart';

/// Base class for organizer events
abstract class OrganizerEvent extends Equatable {
  const OrganizerEvent();

  @override
  List<Object?> get props => [];
}

/// Load organizer profile
class LoadOrganizerProfile extends OrganizerEvent {
  const LoadOrganizerProfile();
}

/// Load organizer's events
class LoadOrganizerEvents extends OrganizerEvent {
  const LoadOrganizerEvents();
}

/// Load admin messages for organizer
class LoadAdminMessages extends OrganizerEvent {
  const LoadAdminMessages();
}

/// Apply to become an organizer
class ApplyAsOrganizer extends OrganizerEvent {
  final OrganizerApplicationParams params;

  const ApplyAsOrganizer(this.params);

  @override
  List<Object?> get props => [params];
}

/// Update organizer profile
class UpdateOrganizerProfile extends OrganizerEvent {
  final UpdateProfileParams params;

  const UpdateOrganizerProfile(this.params);

  @override
  List<Object?> get props => [params];
}

/// Mark admin message as read
class MarkMessageRead extends OrganizerEvent {
  final String messageId;

  const MarkMessageRead(this.messageId);

  @override
  List<Object?> get props => [messageId];
}
