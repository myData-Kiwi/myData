//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ApiClient {
  ApiClient({
    this.basePath = 'http://127.0.0.1:47821',
    this.authentication,
  });

  final String basePath;
  final Authentication? authentication;

  var _client = Client();
  final _defaultHeaderMap = <String, String>{};

  /// Returns the current HTTP [Client] instance to use in this class.
  ///
  /// The return value is guaranteed to never be null.
  Client get client => _client;

  /// Requests to use a new HTTP [Client] in this class.
  set client(Client newClient) {
    _client = newClient;
  }

  Map<String, String> get defaultHeaderMap => _defaultHeaderMap;

  void addDefaultHeader(String key, String value) {
    _defaultHeaderMap[key] = value;
  }

  // We don't use a Map<String, String> for queryParams.
  // If collectionFormat is 'multi', a key might appear multiple times.
  Future<Response> invokeAPI(
    String path,
    String method,
    List<QueryParam> queryParams,
    Object? body,
    Map<String, String> headerParams,
    Map<String, String> formParams,
    String? contentType, {
    Future<void>? abortTrigger,
  }) async {
    await authentication?.applyToParams(queryParams, headerParams);

    headerParams.addAll(_defaultHeaderMap);
    if (contentType != null) {
      headerParams['Content-Type'] = contentType;
    }

    final urlEncodedQueryParams = queryParams.map((param) => '$param');
    final queryString = urlEncodedQueryParams.isNotEmpty
        ? '?${urlEncodedQueryParams.join('&')}'
        : '';
    final uri = Uri.parse('$basePath$path$queryString');

    try {
      // Special case for uploading a single file which isn't a 'multipart/form-data'.
      if (body is MultipartFile &&
          (contentType == null ||
              !contentType.toLowerCase().startsWith('multipart/form-data'))) {
        final request =
            AbortableStreamedRequest(method, uri, abortTrigger: abortTrigger);
        request.headers.addAll(headerParams);
        request.contentLength = body.length;
        body.finalize().listen(
              request.sink.add,
              onDone: request.sink.close,
              // ignore: avoid_types_on_closure_parameters
              onError: (Object error, StackTrace trace) => request.sink.close(),
              cancelOnError: true,
            );
        final response = await _client.send(request);
        return Response.fromStream(response);
      }

      if (body is MultipartRequest) {
        final request =
            AbortableMultipartRequest(method, uri, abortTrigger: abortTrigger);
        request.fields.addAll(body.fields);
        request.files.addAll(body.files);
        request.headers.addAll(body.headers);
        request.headers.addAll(headerParams);
        final response = await _client.send(request);
        return Response.fromStream(response);
      }

      final msgBody = contentType == 'application/x-www-form-urlencoded'
          ? formParams
          : await serializeAsync(body);
      final nullableHeaderParams = headerParams.isEmpty ? null : headerParams;

      final request = AbortableRequest(method, uri, abortTrigger: abortTrigger);
      if (nullableHeaderParams != null) {
        request.headers.addAll(nullableHeaderParams);
      }
      if (msgBody is String && msgBody.isNotEmpty) {
        request.body = msgBody;
      } else if (msgBody is List<int> && msgBody.isNotEmpty) {
        request.bodyBytes = msgBody;
      } else if (msgBody is Map<String, String>) {
        request.bodyFields = msgBody;
      }
      final response = await _client.send(request);
      return Response.fromStream(response);
    } on SocketException catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'Socket operation failed: $method $path',
        error,
        trace,
      );
    } on TlsException catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'TLS/SSL communication failed: $method $path',
        error,
        trace,
      );
    } on IOException catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'I/O operation failed: $method $path',
        error,
        trace,
      );
    } on ClientException catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'HTTP connection failed: $method $path',
        error,
        trace,
      );
    } on Exception catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'Exception occurred: $method $path',
        error,
        trace,
      );
    }
  }

  Future<dynamic> deserializeAsync(
    String value,
    String targetType, {
    bool growable = false,
  }) async =>
      // ignore: deprecated_member_use_from_same_package
      deserialize(value, targetType, growable: growable);

  @Deprecated(
      'Scheduled for removal in OpenAPI Generator 6.x. Use deserializeAsync() instead.')
  dynamic deserialize(
    String value,
    String targetType, {
    bool growable = false,
  }) {
    // Remove all spaces. Necessary for regular expressions as well.
    targetType =
        targetType.replaceAll(' ', ''); // ignore: parameter_assignments

    // If the expected target type is String, nothing to do...
    return targetType == 'String'
        ? value
        : fromJson(json.decode(value), targetType, growable: growable);
  }

  // ignore: deprecated_member_use_from_same_package
  Future<String> serializeAsync(Object? value) async => serialize(value);

  @Deprecated(
      'Scheduled for removal in OpenAPI Generator 6.x. Use serializeAsync() instead.')
  String serialize(Object? value) => value == null ? '' : json.encode(value);

  /// Returns a native instance of an OpenAPI class matching the [specified type][targetType].
  static dynamic fromJson(
    dynamic value,
    String targetType, {
    bool growable = false,
  }) {
    try {
      switch (targetType) {
        case 'String':
          return value is String ? value : value.toString();
        case 'int':
          return value is int ? value : int.parse('$value');
        case 'double':
          return value is double ? value : double.parse('$value');
        case 'bool':
          if (value is bool) {
            return value;
          }
          final valueString = '$value'.toLowerCase();
          return valueString == 'true' || valueString == '1';
        case 'DateTime':
          return value is DateTime ? value : DateTime.tryParse(value);
        case 'AccessIn':
          return AccessIn.fromJson(value);
        case 'AccountIn':
          return AccountIn.fromJson(value);
        case 'AccountOut':
          return AccountOut.fromJson(value);
        case 'AccountSyncOut':
          return AccountSyncOut.fromJson(value);
        case 'AgentCreated':
          return AgentCreated.fromJson(value);
        case 'AgentIn':
          return AgentIn.fromJson(value);
        case 'AgentOut':
          return AgentOut.fromJson(value);
        case 'AppearanceIn':
          return AppearanceIn.fromJson(value);
        case 'AppearanceOut':
          return AppearanceOut.fromJson(value);
        case 'ApprovalOut':
          return ApprovalOut.fromJson(value);
        case 'AssistantSettingsIn':
          return AssistantSettingsIn.fromJson(value);
        case 'BackupOut':
          return BackupOut.fromJson(value);
        case 'CalendarOut':
          return CalendarOut.fromJson(value);
        case 'CardValuesOut':
          return CardValuesOut.fromJson(value);
        case 'ContactDetailOut':
          return ContactDetailOut.fromJson(value);
        case 'ContactField':
          return ContactField.fromJson(value);
        case 'ContactFieldGroup':
          return ContactFieldGroup.fromJson(value);
        case 'ContactIn':
          return ContactIn.fromJson(value);
        case 'ContactOut':
          return ContactOut.fromJson(value);
        case 'ContactWriteOut':
          return ContactWriteOut.fromJson(value);
        case 'CoverageOut':
          return CoverageOut.fromJson(value);
        case 'DecisionIn':
          return DecisionIn.fromJson(value);
        case 'DuplicatePairOut':
          return DuplicatePairOut.fromJson(value);
        case 'ErrorOut':
          return ErrorOut.fromJson(value);
        case 'EventOut':
          return EventOut.fromJson(value);
        case 'EventsOut':
          return EventsOut.fromJson(value);
        case 'FieldErrorsOut':
          return FieldErrorsOut.fromJson(value);
        case 'FollowedChangeOut':
          return FollowedChangeOut.fromJson(value);
        case 'FollowedChangesOut':
          return FollowedChangesOut.fromJson(value);
        case 'FollowedKeepIn':
          return FollowedKeepIn.fromJson(value);
        case 'FollowedSaveIn':
          return FollowedSaveIn.fromJson(value);
        case 'FollowedSeenIn':
          return FollowedSeenIn.fromJson(value);
        case 'GuardError':
          return GuardError.fromJson(value);
        case 'HTTPValidationError':
          return HTTPValidationError.fromJson(value);
        case 'ImportCardOut':
          return ImportCardOut.fromJson(value);
        case 'ImportChoiceIn':
          return ImportChoiceIn.fromJson(value);
        case 'ImportCommitIn':
          return ImportCommitIn.fromJson(value);
        case 'ImportCommittedOut':
          return ImportCommittedOut.fromJson(value);
        case 'ImportConflictOut':
          return ImportConflictOut.fromJson(value);
        case 'ImportCountsOut':
          return ImportCountsOut.fromJson(value);
        case 'ImportItemOut':
          return ImportItemOut.fromJson(value);
        case 'ImportMatchOut':
          return ImportMatchOut.fromJson(value);
        case 'ImportMissingOut':
          return ImportMissingOut.fromJson(value);
        case 'ImportNoteOut':
          return ImportNoteOut.fromJson(value);
        case 'ImportOut':
          return ImportOut.fromJson(value);
        case 'ImportPreviewOut':
          return ImportPreviewOut.fromJson(value);
        case 'ImportRefusedOut':
          return ImportRefusedOut.fromJson(value);
        case 'ImportUndoneOut':
          return ImportUndoneOut.fromJson(value);
        case 'LabeledValue':
          return LabeledValue.fromJson(value);
        case 'LabeledValueIn':
          return LabeledValueIn.fromJson(value);
        case 'MacCalendarOut':
          return MacCalendarOut.fromJson(value);
        case 'MacContainerOut':
          return MacContainerOut.fromJson(value);
        case 'MacSourceIn':
          return MacSourceIn.fromJson(value);
        case 'MemoryOut':
          return MemoryOut.fromJson(value);
        case 'MergeContactIn':
          return MergeContactIn.fromJson(value);
        case 'MergeIn':
          return MergeIn.fromJson(value);
        case 'MergeLeftOutOut':
          return MergeLeftOutOut.fromJson(value);
        case 'MergeLeftOutValueOut':
          return MergeLeftOutValueOut.fromJson(value);
        case 'MergeOut':
          return MergeOut.fromJson(value);
        case 'MergePreviewOut':
          return MergePreviewOut.fromJson(value);
        case 'MessageIn':
          return MessageIn.fromJson(value);
        case 'ModelOut':
          return ModelOut.fromJson(value);
        case 'NotDuplicatesIn':
          return NotDuplicatesIn.fromJson(value);
        case 'NotDuplicatesOut':
          return NotDuplicatesOut.fromJson(value);
        case 'PostalAddress':
          return PostalAddress.fromJson(value);
        case 'PostalAddressIn':
          return PostalAddressIn.fromJson(value);
        case 'PreconditionFailedOut':
          return PreconditionFailedOut.fromJson(value);
        case 'Progress':
          return Progress.fromJson(value);
        case 'ReaderIn':
          return ReaderIn.fromJson(value);
        case 'SourceOut':
          return SourceOut.fromJson(value);
        case 'SourcesOut':
          return SourcesOut.fromJson(value);
        case 'StatusOut':
          return StatusOut.fromJson(value);
        case 'StopFollowingOut':
          return StopFollowingOut.fromJson(value);
        case 'SyncCounts':
          return SyncCounts.fromJson(value);
        case 'SyncOut':
          return SyncOut.fromJson(value);
        case 'ThemeOut':
          return ThemeOut.fromJson(value);
        case 'ToolOut':
          return ToolOut.fromJson(value);
        case 'TrashItemOut':
          return TrashItemOut.fromJson(value);
        case 'UndoOut':
          return UndoOut.fromJson(value);
        case 'ValidationError':
          return ValidationError.fromJson(value);
        case 'WindowOut':
          return WindowOut.fromJson(value);
        default:
          dynamic match;
          if (value is List &&
              (match = _regList.firstMatch(targetType)?.group(1)) != null) {
            return value
                .map<dynamic>((dynamic v) => fromJson(
                      v,
                      match,
                      growable: growable,
                    ))
                .toList(growable: growable);
          }
          if (value is Set &&
              (match = _regSet.firstMatch(targetType)?.group(1)) != null) {
            return value
                .map<dynamic>((dynamic v) => fromJson(
                      v,
                      match,
                      growable: growable,
                    ))
                .toSet();
          }
          if (value is Map &&
              (match = _regMap.firstMatch(targetType)?.group(1)) != null) {
            return Map<String, dynamic>.fromIterables(
              value.keys.cast<String>(),
              value.values.map<dynamic>((dynamic v) => fromJson(
                    v,
                    match,
                    growable: growable,
                  )),
            );
          }
      }
    } on Exception catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.internalServerError,
        'Exception during deserialization.',
        error,
        trace,
      );
    }
    throw ApiException(
      HttpStatus.internalServerError,
      'Could not find a suitable class for deserialization',
    );
  }
}

/// Primarily intended for use in an isolate.
class DeserializationMessage {
  const DeserializationMessage({
    required this.json,
    required this.targetType,
    this.growable = false,
  });

  /// The JSON value to deserialize.
  final String json;

  /// Target type to deserialize to.
  final String targetType;

  /// Whether to make deserialized lists or maps growable.
  final bool growable;
}

/// Primarily intended for use in an isolate.
Future<dynamic> decodeAsync(DeserializationMessage message) async {
  // Remove all spaces. Necessary for regular expressions as well.
  final targetType = message.targetType.replaceAll(' ', '');

  // If the expected target type is String, nothing to do...
  return targetType == 'String' ? message.json : json.decode(message.json);
}

/// Primarily intended for use in an isolate.
Future<dynamic> deserializeAsync(DeserializationMessage message) async {
  // Remove all spaces. Necessary for regular expressions as well.
  final targetType = message.targetType.replaceAll(' ', '');

  // If the expected target type is String, nothing to do...
  return targetType == 'String'
      ? message.json
      : ApiClient.fromJson(
          json.decode(message.json),
          targetType,
          growable: message.growable,
        );
}

/// Primarily intended for use in an isolate.
Future<String> serializeAsync(Object? value) async =>
    value == null ? '' : json.encode(value);
