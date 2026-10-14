//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ImportsApi {
  ImportsApi([ApiClient? apiClient])
      : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Commit Import
  ///
  /// Import the preview as one batch into an owned address book, after a snapshot of the databases. Each card gets its default action unless `choices` names another; nothing is merged. A preview with losses needs accept_losses. Cards that changed both in the input and on the host since an earlier import are reported as conflicts and not written; contacts an earlier import brought in that the input no longer has are reported as missing and kept. POST /imports/{id}/undo undoes the whole import.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] previewId (required):
  ///
  /// * [ImportCommitIn] importCommitIn (required):
  Future<Response> commitImportWithHttpInfo(
    String previewId,
    ImportCommitIn importCommitIn, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/import/previews/{preview_id}/commit'
        .replaceAll('{preview_id}', previewId);

    // ignore: prefer_final_locals
    Object? postBody = importCommitIn;

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

  /// Commit Import
  ///
  /// Import the preview as one batch into an owned address book, after a snapshot of the databases. Each card gets its default action unless `choices` names another; nothing is merged. A preview with losses needs accept_losses. Cards that changed both in the input and on the host since an earlier import are reported as conflicts and not written; contacts an earlier import brought in that the input no longer has are reported as missing and kept. POST /imports/{id}/undo undoes the whole import.
  ///
  /// Parameters:
  ///
  /// * [String] previewId (required):
  ///
  /// * [ImportCommitIn] importCommitIn (required):
  Future<ImportCommittedOut?> commitImport(
    String previewId,
    ImportCommitIn importCommitIn, {
    Future<void>? abortTrigger,
  }) async {
    final response = await commitImportWithHttpInfo(
      previewId,
      importCommitIn,
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
        'ImportCommittedOut',
      ) as ImportCommittedOut;
    }
    return null;
  }

  /// Discard Import Preview
  ///
  /// Drop a preview the app cancelled, with the file's contents the host holds for it. Only the app that made it can drop it.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] previewId (required):
  Future<Response> discardImportPreviewWithHttpInfo(
    String previewId, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path =
        r'/import/previews/{preview_id}'.replaceAll('{preview_id}', previewId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];

    return apiClient.invokeAPI(
      path,
      'DELETE',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Discard Import Preview
  ///
  /// Drop a preview the app cancelled, with the file's contents the host holds for it. Only the app that made it can drop it.
  ///
  /// Parameters:
  ///
  /// * [String] previewId (required):
  Future<void> discardImportPreview(
    String previewId, {
    Future<void>? abortTrigger,
  }) async {
    final response = await discardImportPreviewWithHttpInfo(
      previewId,
      abortTrigger: abortTrigger,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Import History
  ///
  /// Every import, the newest first: when, from where, its counts and whether it was undone.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> importHistoryWithHttpInfo({
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/imports';

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

  /// Import History
  ///
  /// Every import, the newest first: when, from where, its counts and whether it was undone.
  Future<List<ImportOut>?> importHistory({
    Future<void>? abortTrigger,
  }) async {
    final response = await importHistoryWithHttpInfo(
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
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<ImportOut>')
              as List)
          .cast<ImportOut>()
          .toList(growable: false);
    }
    return null;
  }

  /// Import Preview
  ///
  /// A preview again, analysed as the host is now. Only the app that made it can read it.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] previewId (required):
  Future<Response> importPreviewWithHttpInfo(
    String previewId, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path =
        r'/import/previews/{preview_id}'.replaceAll('{preview_id}', previewId);

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

  /// Import Preview
  ///
  /// A preview again, analysed as the host is now. Only the app that made it can read it.
  ///
  /// Parameters:
  ///
  /// * [String] previewId (required):
  Future<ImportPreviewOut?> importPreview(
    String previewId, {
    Future<void>? abortTrigger,
  }) async {
    final response = await importPreviewWithHttpInfo(
      previewId,
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
        'ImportPreviewOut',
      ) as ImportPreviewOut;
    }
    return null;
  }

  /// Import Preview Item
  ///
  /// One card of a preview with its values, in the shape of a contact's page, to compare it with a contact it matches (\"In the file\" beside \"In myData\"). Only the app that made the preview can read it.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] previewId (required):
  ///
  /// * [int] index (required):
  Future<Response> importPreviewItemWithHttpInfo(
    String previewId,
    int index, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/import/previews/{preview_id}/items/{index}'
        .replaceAll('{preview_id}', previewId)
        .replaceAll('{index}', index.toString());

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

  /// Import Preview Item
  ///
  /// One card of a preview with its values, in the shape of a contact's page, to compare it with a contact it matches (\"In the file\" beside \"In myData\"). Only the app that made the preview can read it.
  ///
  /// Parameters:
  ///
  /// * [String] previewId (required):
  ///
  /// * [int] index (required):
  Future<ImportCardOut?> importPreviewItem(
    String previewId,
    int index, {
    Future<void>? abortTrigger,
  }) async {
    final response = await importPreviewItemWithHttpInfo(
      previewId,
      index,
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
        'ImportCardOut',
      ) as ImportCardOut;
    }
    return null;
  }

  /// Preview Contacts Import
  ///
  /// Read a .vcf (vCard 2.1, 3.0 or 4.0) or a .zip of them, sent as the request body, into a preview held for an hour: counts, every card's status and default action, matches with your contacts and followed ones, the loss report and what changes. Nothing is written. The zip is read in memory, never extracted.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [MultipartFile] body (required):
  ///   the file's bytes as they are (a .vcf, or a .zip of .vcf files), at most 50 MB
  ///
  /// * [String] filename:
  ///   the file's name, shown in the history; never opened as a path
  Future<Response> previewContactsImportWithHttpInfo(
    MultipartFile body, {
    String? filename,
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/import/contacts/preview';

    // ignore: prefer_final_locals
    Object? postBody = body;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (filename != null) {
      queryParams.addAll(_queryParams('', 'filename', filename));
    }

    const contentTypes = <String>['application/octet-stream'];

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

  /// Preview Contacts Import
  ///
  /// Read a .vcf (vCard 2.1, 3.0 or 4.0) or a .zip of them, sent as the request body, into a preview held for an hour: counts, every card's status and default action, matches with your contacts and followed ones, the loss report and what changes. Nothing is written. The zip is read in memory, never extracted.
  ///
  /// Parameters:
  ///
  /// * [MultipartFile] body (required):
  ///   the file's bytes as they are (a .vcf, or a .zip of .vcf files), at most 50 MB
  ///
  /// * [String] filename:
  ///   the file's name, shown in the history; never opened as a path
  Future<ImportPreviewOut?> previewContactsImport(
    MultipartFile body, {
    String? filename,
    Future<void>? abortTrigger,
  }) async {
    final response = await previewContactsImportWithHttpInfo(
      body,
      filename: filename,
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
        'ImportPreviewOut',
      ) as ImportPreviewOut;
    }
    return null;
  }

  /// Preview Source Import
  ///
  /// A preview of importing a copy of a followed iCloud account's contacts (as the mirror holds them, so nothing is lost). Once imported, each followed card is hidden behind its owned copy while the account is still followed; stop_following says the account can be unfollowed. This Mac is never imported (409).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] accountId (required):
  Future<Response> previewSourceImportWithHttpInfo(
    String accountId, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/import/contacts/from-source/{account_id}/preview'
        .replaceAll('{account_id}', accountId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];

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

  /// Preview Source Import
  ///
  /// A preview of importing a copy of a followed iCloud account's contacts (as the mirror holds them, so nothing is lost). Once imported, each followed card is hidden behind its owned copy while the account is still followed; stop_following says the account can be unfollowed. This Mac is never imported (409).
  ///
  /// Parameters:
  ///
  /// * [String] accountId (required):
  Future<ImportPreviewOut?> previewSourceImport(
    String accountId, {
    Future<void>? abortTrigger,
  }) async {
    final response = await previewSourceImportWithHttpInfo(
      accountId,
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
        'ImportPreviewOut',
      ) as ImportPreviewOut;
    }
    return null;
  }

  /// Undo Import
  ///
  /// Undo a whole import: what it created and nobody changed since goes to Recently deleted, what it updated gets its earlier text back. Anything changed since is kept and listed. Nothing is deleted for good. Works once, also after a restart.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] importId (required):
  Future<Response> undoImportWithHttpInfo(
    String importId, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path =
        r'/imports/{import_id}/undo'.replaceAll('{import_id}', importId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];

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

  /// Undo Import
  ///
  /// Undo a whole import: what it created and nobody changed since goes to Recently deleted, what it updated gets its earlier text back. Anything changed since is kept and listed. Nothing is deleted for good. Works once, also after a restart.
  ///
  /// Parameters:
  ///
  /// * [String] importId (required):
  Future<ImportUndoneOut?> undoImport(
    String importId, {
    Future<void>? abortTrigger,
  }) async {
    final response = await undoImportWithHttpInfo(
      importId,
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
        'ImportUndoneOut',
      ) as ImportUndoneOut;
    }
    return null;
  }
}
