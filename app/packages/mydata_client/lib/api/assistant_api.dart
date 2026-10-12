//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AssistantApi {
  AssistantApi([ApiClient? apiClient])
      : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Assistant Settings
  ///
  /// Switch the assistant on (the model is prepared, downloading it if needed) or off (nothing is downloaded or loaded; the rest of myData works without it).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [AssistantSettingsIn] assistantSettingsIn (required):
  Future<Response> assistantSettingsWithHttpInfo(
    AssistantSettingsIn assistantSettingsIn, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/assistant/settings';

    // ignore: prefer_final_locals
    Object? postBody = assistantSettingsIn;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];

    return apiClient.invokeAPI(
      path,
      'PUT',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Assistant Settings
  ///
  /// Switch the assistant on (the model is prepared, downloading it if needed) or off (nothing is downloaded or loaded; the rest of myData works without it).
  ///
  /// Parameters:
  ///
  /// * [AssistantSettingsIn] assistantSettingsIn (required):
  Future<StatusOut?> assistantSettings(
    AssistantSettingsIn assistantSettingsIn, {
    Future<void>? abortTrigger,
  }) async {
    final response = await assistantSettingsWithHttpInfo(
      assistantSettingsIn,
      abortTrigger: abortTrigger,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'StatusOut',
      ) as StatusOut;
    }
    return null;
  }

  /// Messages
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [MessageIn] messageIn (required):
  Future<Response> messagesWithHttpInfo(
    MessageIn messageIn, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/assistant/messages';

    // ignore: prefer_final_locals
    Object? postBody = messageIn;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];

    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Messages
  ///
  /// Parameters:
  ///
  /// * [MessageIn] messageIn (required):
  Future<String?> messages(
    MessageIn messageIn, {
    Future<void>? abortTrigger,
  }) async {
    final response = await messagesWithHttpInfo(
      messageIn,
      abortTrigger: abortTrigger,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'String',
      ) as String;
    }
    return null;
  }
}
