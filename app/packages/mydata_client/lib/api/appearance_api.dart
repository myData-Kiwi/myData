//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AppearanceApi {
  AppearanceApi([ApiClient? apiClient])
      : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Appearance
  ///
  /// The theme every app uses, and the themes to choose from. Light or dark mode is per device.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> appearanceWithHttpInfo({
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/appearance';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];

    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Appearance
  ///
  /// The theme every app uses, and the themes to choose from. Light or dark mode is per device.
  Future<AppearanceOut?> appearance({
    Future<void>? abortTrigger,
  }) async {
    final response = await appearanceWithHttpInfo(
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
        'AppearanceOut',
      ) as AppearanceOut;
    }
    return null;
  }

  /// Set Appearance
  ///
  /// Set the theme every app uses. Apps follow the change through GET /status.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [AppearanceIn] appearanceIn (required):
  Future<Response> setAppearanceWithHttpInfo(
    AppearanceIn appearanceIn, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/appearance';

    // ignore: prefer_final_locals
    Object? postBody = appearanceIn;

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

  /// Set Appearance
  ///
  /// Set the theme every app uses. Apps follow the change through GET /status.
  ///
  /// Parameters:
  ///
  /// * [AppearanceIn] appearanceIn (required):
  Future<AppearanceOut?> setAppearance(
    AppearanceIn appearanceIn, {
    Future<void>? abortTrigger,
  }) async {
    final response = await setAppearanceWithHttpInfo(
      appearanceIn,
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
        'AppearanceOut',
      ) as AppearanceOut;
    }
    return null;
  }
}
