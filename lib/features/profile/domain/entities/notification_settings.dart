/// What the patient agrees to be contacted about.
///
/// Four switches, and each one is a real preference the backend acts on rather
/// than a row that only remembers itself. The defaults are the ones the person
/// would have chosen: on for the two that are about a consultation they asked
/// for, off for marketing — nobody opts into promotions by accident.
class NotificationSettings {
  const NotificationSettings({
    this.consultationReminders = true,
    this.chatMessages = true,
    this.promotions = false,
    this.emailUpdates = false,
  });

  /// A doctor accepting, a call starting, an appointment coming up.
  final bool consultationReminders;

  /// A message from a doctor in a consultation thread.
  final bool chatMessages;

  final bool promotions;

  /// The same content by email as well as in the app.
  final bool emailUpdates;

  NotificationSettings copyWith({
    bool? consultationReminders,
    bool? chatMessages,
    bool? promotions,
    bool? emailUpdates,
  }) {
    return NotificationSettings(
      consultationReminders:
          consultationReminders ?? this.consultationReminders,
      chatMessages: chatMessages ?? this.chatMessages,
      promotions: promotions ?? this.promotions,
      emailUpdates: emailUpdates ?? this.emailUpdates,
    );
  }
}

/// One switch on the settings screen.
///
/// An enum rather than four hand-written rows, so the screen is a loop and a
/// fifth preference is one entry here plus one field above — not a fifth copy
/// of the same twenty lines.
enum PatientNotificationToggle {
  consultationReminders(
    'Consultation updates',
    'When a doctor accepts, and when a call is about to start.',
  ),
  chatMessages(
    'Chat messages',
    'When a doctor replies in a consultation thread.',
  ),
  promotions(
    'Offers and health tips',
    'Occasional news from the platform. Off by default.',
  ),
  emailUpdates(
    'Email as well as in-app',
    'Send the same updates to your email address.',
  );

  const PatientNotificationToggle(this.label, this.description);

  final String label;
  final String description;

  bool from(NotificationSettings settings) => switch (this) {
    PatientNotificationToggle.consultationReminders =>
      settings.consultationReminders,
    PatientNotificationToggle.chatMessages => settings.chatMessages,
    PatientNotificationToggle.promotions => settings.promotions,
    PatientNotificationToggle.emailUpdates => settings.emailUpdates,
  };

  NotificationSettings applyTo(NotificationSettings settings, bool value) =>
      switch (this) {
        PatientNotificationToggle.consultationReminders => settings.copyWith(
          consultationReminders: value,
        ),
        PatientNotificationToggle.chatMessages => settings.copyWith(
          chatMessages: value,
        ),
        PatientNotificationToggle.promotions => settings.copyWith(
          promotions: value,
        ),
        PatientNotificationToggle.emailUpdates => settings.copyWith(
          emailUpdates: value,
        ),
      };

  /// The single-field body `PATCH /patients/me/settings` expects.
  ///
  /// One key, not four. A screen that sent every switch could undo a change
  /// made on another device between the read and the write.
  Map<String, Object?> payload(bool value) => {name: value};
}
