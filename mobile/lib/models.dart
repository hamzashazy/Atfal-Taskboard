/// Data models mirroring src/lib/types.ts of the web app.
/// Status/category/role stay as raw strings — the database is the source of
/// truth for allowed values and the UI maps them through meta.dart.
library;

class SessionUser {
  final String token;
  final String userId;
  final String username;
  final String displayName;
  final String role; // admin | city_head
  final int? cityId;
  final String? cityName;
  final String? email;
  final String? contactNo;

  SessionUser({
    required this.token,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.role,
    this.cityId,
    this.cityName,
    this.email,
    this.contactNo,
  });

  bool get isAdmin => role == 'admin';
  bool get isCityHead => role == 'city_head';

  SessionUser copyWith({String? email, String? contactNo}) => SessionUser(
        token: token,
        userId: userId,
        username: username,
        displayName: displayName,
        role: role,
        cityId: cityId,
        cityName: cityName,
        email: email ?? this.email,
        contactNo: contactNo ?? this.contactNo,
      );

  factory SessionUser.fromJson(Map<String, dynamic> j) => SessionUser(
        token: j['token'] as String,
        userId: j['user_id'] as String,
        username: j['username'] as String,
        displayName: j['display_name'] as String,
        role: j['role'] as String,
        cityId: j['city_id'] as int?,
        cityName: j['city_name'] as String?,
        email: j['email'] as String?,
        contactNo: j['contact_no'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'token': token,
        'user_id': userId,
        'username': username,
        'display_name': displayName,
        'role': role,
        'city_id': cityId,
        'city_name': cityName,
        'email': email,
        'contact_no': contactNo,
      };
}

class City {
  final int id;
  final String name;
  final String? region;
  final bool active;

  City({required this.id, required this.name, this.region, required this.active});

  factory City.fromJson(Map<String, dynamic> j) => City(
        id: j['id'] as int,
        name: j['name'] as String,
        region: j['region'] as String?,
        active: j['active'] as bool,
      );
}

class Task {
  final String id;
  final String title;
  final String? description;
  final String category;
  final String? dueDate; // yyyy-MM-dd
  final String? attachmentUrl;
  final bool archived;
  final String createdAt;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    this.dueDate,
    this.attachmentUrl,
    required this.archived,
    required this.createdAt,
  });

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        category: j['category'] as String,
        dueDate: j['due_date'] as String?,
        attachmentUrl: j['attachment_url'] as String?,
        archived: j['archived'] as bool,
        createdAt: j['created_at'] as String,
      );
}

class Assignment {
  final String id;
  final String taskId;
  final int cityId;
  final String status; // pending | in_progress | submitted | approved | returned
  final String? note;
  final String? proofUrl;
  final String? reviewNote;
  final String? submittedAt;
  final String? reviewedAt;
  final String updatedAt;

  Assignment({
    required this.id,
    required this.taskId,
    required this.cityId,
    required this.status,
    this.note,
    this.proofUrl,
    this.reviewNote,
    this.submittedAt,
    this.reviewedAt,
    required this.updatedAt,
  });

  factory Assignment.fromJson(Map<String, dynamic> j) => Assignment(
        id: j['id'] as String,
        taskId: j['task_id'] as String,
        cityId: j['city_id'] as int,
        status: j['status'] as String,
        note: j['note'] as String?,
        proofUrl: j['proof_url'] as String?,
        reviewNote: j['review_note'] as String?,
        submittedAt: j['submitted_at'] as String?,
        reviewedAt: j['reviewed_at'] as String?,
        updatedAt: j['updated_at'] as String,
      );
}

class Activity {
  final int id;
  final String? assignmentId;
  final String actorName;
  final String action;
  final String? detail;
  final String createdAt;

  Activity({
    required this.id,
    this.assignmentId,
    required this.actorName,
    required this.action,
    this.detail,
    required this.createdAt,
  });

  factory Activity.fromJson(Map<String, dynamic> j) => Activity(
        id: j['id'] as int,
        assignmentId: j['assignment_id'] as String?,
        actorName: j['actor_name'] as String,
        action: j['action'] as String,
        detail: j['detail'] as String?,
        createdAt: j['created_at'] as String,
      );
}

class UserRow {
  final String id;
  final String username;
  final String displayName;
  final String role;
  final int? cityId;
  final String? cityName;
  final bool active;
  final String? email;
  final String? contactNo;

  UserRow({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    this.cityId,
    this.cityName,
    required this.active,
    this.email,
    this.contactNo,
  });

  factory UserRow.fromJson(Map<String, dynamic> j) => UserRow(
        id: j['id'] as String,
        username: j['username'] as String,
        displayName: j['display_name'] as String,
        role: j['role'] as String,
        cityId: j['city_id'] as int?,
        cityName: j['city_name'] as String?,
        active: j['active'] as bool,
        email: j['email'] as String?,
        contactNo: j['contact_no'] as String?,
      );
}

class SignupRequest {
  final String id;
  final String fullName;
  final String email;
  final String contactNo;
  final int cityId;
  final String cityName;
  final String status;
  final String? reviewNote;
  final String createdAt;

  SignupRequest({
    required this.id,
    required this.fullName,
    required this.email,
    required this.contactNo,
    required this.cityId,
    required this.cityName,
    required this.status,
    this.reviewNote,
    required this.createdAt,
  });

  factory SignupRequest.fromJson(Map<String, dynamic> j) => SignupRequest(
        id: j['id'] as String,
        fullName: j['full_name'] as String,
        email: j['email'] as String,
        contactNo: j['contact_no'] as String,
        cityId: j['city_id'] as int,
        cityName: j['city_name'] as String,
        status: j['status'] as String,
        reviewNote: j['review_note'] as String?,
        createdAt: j['created_at'] as String,
      );
}
