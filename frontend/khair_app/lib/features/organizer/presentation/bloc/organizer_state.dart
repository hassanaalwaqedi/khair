part of 'organizer_bloc.dart';

/// Status of organizer operations
enum OrganizerStatus { initial, loading, success, failure }

/// State for organizer BLoC
class OrganizerState extends Equatable {
  final OrganizerStatus profileStatus;
  final OrganizerStatus eventsStatus;
  final OrganizerStatus messagesStatus;
  final OrganizerStatus applicationStatus;
  final Organizer? organizer;
  final List<Event> events;
  final List<AdminMessage> messages;
  final String? errorMessage;

  const OrganizerState({
    this.profileStatus = OrganizerStatus.initial,
    this.eventsStatus = OrganizerStatus.initial,
    this.messagesStatus = OrganizerStatus.initial,
    this.applicationStatus = OrganizerStatus.initial,
    this.organizer,
    this.events = const [],
    this.messages = const [],
    this.errorMessage,
  });

  OrganizerState copyWith({
    OrganizerStatus? profileStatus,
    OrganizerStatus? eventsStatus,
    OrganizerStatus? messagesStatus,
    OrganizerStatus? applicationStatus,
    Organizer? organizer,
    List<Event>? events,
    List<AdminMessage>? messages,
    String? errorMessage,
  }) {
    return OrganizerState(
      profileStatus: profileStatus ?? this.profileStatus,
      eventsStatus: eventsStatus ?? this.eventsStatus,
      messagesStatus: messagesStatus ?? this.messagesStatus,
      applicationStatus: applicationStatus ?? this.applicationStatus,
      organizer: organizer ?? this.organizer,
      events: events ?? this.events,
      messages: messages ?? this.messages,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Convenience getters for status checks
  bool get isProfileLoading => profileStatus == OrganizerStatus.loading;
  bool get isEventsLoading => eventsStatus == OrganizerStatus.loading;
  bool get isMessagesLoading => messagesStatus == OrganizerStatus.loading;
  bool get isApplicationLoading => applicationStatus == OrganizerStatus.loading;

  bool get hasProfile => organizer != null;
  bool get hasEvents => events.isNotEmpty;
  bool get hasMessages => messages.isNotEmpty;
  bool get hasUnreadMessages => messages.any((m) => !m.isRead);

  int get unreadMessageCount => messages.where((m) => !m.isRead).length;

  @override
  List<Object?> get props => [
        profileStatus,
        eventsStatus,
        messagesStatus,
        applicationStatus,
        organizer,
        events,
        messages,
        errorMessage,
      ];
}
