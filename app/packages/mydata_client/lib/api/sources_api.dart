//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SourcesApi {
  SourcesApi([ApiClient? apiClient])
      : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Accounts
  ///
  /// Linked accounts. Passwords are never returned.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> accountsWithHttpInfo({
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/accounts';

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

  /// Accounts
  ///
  /// Linked accounts. Passwords are never returned.
  Future<List<AccountOut>?> accounts({
    Future<void>? abortTrigger,
  }) async {
    final response = await accountsWithHttpInfo(
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
      return (await apiClient.deserializeAsync(responseBody, 'List<AccountOut>')
              as List)
          .cast<AccountOut>()
          .toList(growable: false);
    }
    return null;
  }

  /// Add Account
  ///
  /// Link an account. The provider checks the email and password first (discovery); nothing is stored unless that succeeds. Then the host mirrors its contacts and calendars, read-only, and switches to real mode.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [AccountIn] accountIn (required):
  Future<Response> addAccountWithHttpInfo(
    AccountIn accountIn, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/accounts';

    // ignore: prefer_final_locals
    Object? postBody = accountIn;

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

  /// Add Account
  ///
  /// Link an account. The provider checks the email and password first (discovery); nothing is stored unless that succeeds. Then the host mirrors its contacts and calendars, read-only, and switches to real mode.
  ///
  /// Parameters:
  ///
  /// * [AccountIn] accountIn (required):
  Future<AccountOut?> addAccount(
    AccountIn accountIn, {
    Future<void>? abortTrigger,
  }) async {
    final response = await addAccountWithHttpInfo(
      accountIn,
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
        'AccountOut',
      ) as AccountOut;
    }
    return null;
  }

  /// Calendars
  ///
  /// Every mirrored calendar, grouped by source: This Mac first, then each iCloud account. The same calendar seen through This Mac and through an iCloud account is listed twice, once per source.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> calendarsWithHttpInfo({
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/calendars';

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

  /// Calendars
  ///
  /// Every mirrored calendar, grouped by source: This Mac first, then each iCloud account. The same calendar seen through This Mac and through an iCloud account is listed twice, once per source.
  Future<List<CalendarOut>?> calendars({
    Future<void>? abortTrigger,
  }) async {
    final response = await calendarsWithHttpInfo(
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
      return (await apiClient.deserializeAsync(
              responseBody, 'List<CalendarOut>') as List)
          .cast<CalendarOut>()
          .toList(growable: false);
    }
    return null;
  }

  /// Configure Mac
  ///
  /// Turn This Mac on or off, and choose which contact accounts and calendars it includes (null: all). Fields left out keep their value. Turning it off stops its reader and deletes everything it mirrored; leaving out an account or calendar deletes what was mirrored from it. Copies in the host's snapshots stay until they expire (within 12 months while the host runs). With no source on, the host is back in demo mode.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [MacSourceIn] macSourceIn (required):
  Future<Response> configureMacWithHttpInfo(
    MacSourceIn macSourceIn, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/sources/mac';

    // ignore: prefer_final_locals
    Object? postBody = macSourceIn;

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

  /// Configure Mac
  ///
  /// Turn This Mac on or off, and choose which contact accounts and calendars it includes (null: all). Fields left out keep their value. Turning it off stops its reader and deletes everything it mirrored; leaving out an account or calendar deletes what was mirrored from it. Copies in the host's snapshots stay until they expire (within 12 months while the host runs). With no source on, the host is back in demo mode.
  ///
  /// Parameters:
  ///
  /// * [MacSourceIn] macSourceIn (required):
  Future<SourceOut?> configureMac(
    MacSourceIn macSourceIn, {
    Future<void>? abortTrigger,
  }) async {
    final response = await configureMacWithHttpInfo(
      macSourceIn,
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
        'SourceOut',
      ) as SourceOut;
    }
    return null;
  }

  /// Contact
  ///
  /// One contact, for its page: the fields grouped by kind, the job title and where the card comes from; whether it can be changed here, and its etag (also the ETag header).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] contactId (required):
  ///
  /// * [bool] raw:
  ///   include the raw vCard
  Future<Response> contactWithHttpInfo(
    String contactId, {
    bool? raw,
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path =
        r'/contacts/{contact_id}'.replaceAll('{contact_id}', contactId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (raw != null) {
      queryParams.addAll(_queryParams('', 'raw', raw));
    }

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

  /// Contact
  ///
  /// One contact, for its page: the fields grouped by kind, the job title and where the card comes from; whether it can be changed here, and its etag (also the ETag header).
  ///
  /// Parameters:
  ///
  /// * [String] contactId (required):
  ///
  /// * [bool] raw:
  ///   include the raw vCard
  Future<ContactDetailOut?> contact(
    String contactId, {
    bool? raw,
    Future<void>? abortTrigger,
  }) async {
    final response = await contactWithHttpInfo(
      contactId,
      raw: raw,
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
        'ContactDetailOut',
      ) as ContactDetailOut;
    }
    return null;
  }

  /// Contact Photo
  ///
  /// The contact's photo, as JPEG or PNG. 404 when there is none: the app shows initials.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] contactId (required):
  Future<Response> contactPhotoWithHttpInfo(
    String contactId, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path =
        r'/contacts/{contact_id}/photo'.replaceAll('{contact_id}', contactId);

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

  /// Contact Photo
  ///
  /// The contact's photo, as JPEG or PNG. 404 when there is none: the app shows initials.
  ///
  /// Parameters:
  ///
  /// * [String] contactId (required):
  Future<MultipartFile?> contactPhoto(
    String contactId, {
    Future<void>? abortTrigger,
  }) async {
    final response = await contactPhotoWithHttpInfo(
      contactId,
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
        'MultipartFile',
      ) as MultipartFile;
    }
    return null;
  }

  /// Contacts
  ///
  /// Mirrored contacts by name, or the ones matching `query` (every word, as a prefix).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] query:
  ///   search names, organisation, emails and phones
  ///
  /// * [int] limit:
  ///
  /// * [int] offset:
  Future<Response> contactsWithHttpInfo({
    String? query,
    int? limit,
    int? offset,
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/contacts';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (query != null) {
      queryParams.addAll(_queryParams('', 'query', query));
    }
    if (limit != null) {
      queryParams.addAll(_queryParams('', 'limit', limit));
    }
    if (offset != null) {
      queryParams.addAll(_queryParams('', 'offset', offset));
    }

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

  /// Contacts
  ///
  /// Mirrored contacts by name, or the ones matching `query` (every word, as a prefix).
  ///
  /// Parameters:
  ///
  /// * [String] query:
  ///   search names, organisation, emails and phones
  ///
  /// * [int] limit:
  ///
  /// * [int] offset:
  Future<List<ContactOut>?> contacts({
    String? query,
    int? limit,
    int? offset,
    Future<void>? abortTrigger,
  }) async {
    final response = await contactsWithHttpInfo(
      query: query,
      limit: limit,
      offset: offset,
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
      return (await apiClient.deserializeAsync(responseBody, 'List<ContactOut>')
              as List)
          .cast<ContactOut>()
          .toList(growable: false);
    }
    return null;
  }

  /// Create Contact
  ///
  /// Create a contact the host owns, in its \"myData\" address book (made with the first contact, which also switches the host to real mode). It is on myData only, not on any phone yet (on_phone false).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [ContactIn] contactIn (required):
  Future<Response> createContactWithHttpInfo(
    ContactIn contactIn, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/contacts';

    // ignore: prefer_final_locals
    Object? postBody = contactIn;

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

  /// Create Contact
  ///
  /// Create a contact the host owns, in its \"myData\" address book (made with the first contact, which also switches the host to real mode). It is on myData only, not on any phone yet (on_phone false).
  ///
  /// Parameters:
  ///
  /// * [ContactIn] contactIn (required):
  Future<ContactWriteOut?> createContact(
    ContactIn contactIn, {
    Future<void>? abortTrigger,
  }) async {
    final response = await createContactWithHttpInfo(
      contactIn,
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
        'ContactWriteOut',
      ) as ContactWriteOut;
    }
    return null;
  }

  /// Delete Contact
  ///
  /// Move an owned contact to Recently deleted. It is deleted for good after 30 days (purge_after); until then POST /trash/{id}/restore or the undo id brings it back. Copies in the host's snapshots stay until those expire (within 12 months while the host runs).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] contactId (required):
  ///
  /// * [String] ifMatch:
  ///   optional: refuse if the contact changed since
  Future<Response> deleteContactWithHttpInfo(
    String contactId, {
    String? ifMatch,
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path =
        r'/contacts/{contact_id}'.replaceAll('{contact_id}', contactId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (ifMatch != null) {
      headerParams[r'If-Match'] = parameterToString(ifMatch);
    }

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

  /// Delete Contact
  ///
  /// Move an owned contact to Recently deleted. It is deleted for good after 30 days (purge_after); until then POST /trash/{id}/restore or the undo id brings it back. Copies in the host's snapshots stay until those expire (within 12 months while the host runs).
  ///
  /// Parameters:
  ///
  /// * [String] contactId (required):
  ///
  /// * [String] ifMatch:
  ///   optional: refuse if the contact changed since
  Future<ContactWriteOut?> deleteContact(
    String contactId, {
    String? ifMatch,
    Future<void>? abortTrigger,
  }) async {
    final response = await deleteContactWithHttpInfo(
      contactId,
      ifMatch: ifMatch,
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
        'ContactWriteOut',
      ) as ContactWriteOut;
    }
    return null;
  }

  /// Events
  ///
  /// Events overlapping the days from start to end (both included), in the host's time zone, with recurring events expanded into occurrences; and, per source, which of those days it holds. This Mac holds a window (one year back, two ahead): days outside it are unknown, not empty.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [DateTime] start (required):
  ///   first day, YYYY-MM-DD
  ///
  /// * [DateTime] end (required):
  ///   last day, YYYY-MM-DD (included)
  ///
  /// * [List<String?>] calendar:
  ///   calendar ids; repeat for several. Omit for every calendar
  Future<Response> eventsWithHttpInfo(
    DateTime start,
    DateTime end, {
    List<String?>? calendar,
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/events';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    queryParams.addAll(_queryParams('', 'start', start));
    queryParams.addAll(_queryParams('', 'end', end));
    if (calendar != null) {
      queryParams.addAll(_queryParams('multi', 'calendar', calendar));
    }

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

  /// Events
  ///
  /// Events overlapping the days from start to end (both included), in the host's time zone, with recurring events expanded into occurrences; and, per source, which of those days it holds. This Mac holds a window (one year back, two ahead): days outside it are unknown, not empty.
  ///
  /// Parameters:
  ///
  /// * [DateTime] start (required):
  ///   first day, YYYY-MM-DD
  ///
  /// * [DateTime] end (required):
  ///   last day, YYYY-MM-DD (included)
  ///
  /// * [List<String?>] calendar:
  ///   calendar ids; repeat for several. Omit for every calendar
  Future<EventsOut?> events(
    DateTime start,
    DateTime end, {
    List<String?>? calendar,
    Future<void>? abortTrigger,
  }) async {
    final response = await eventsWithHttpInfo(
      start,
      end,
      calendar: calendar,
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
        'EventsOut',
      ) as EventsOut;
    }
    return null;
  }

  /// Purge Item
  ///
  /// Delete an item in Recently deleted for good now, with its earlier versions; it cannot be brought back or undone. Copies in the host's snapshots stay until those expire (backups_kept_until).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] itemId (required):
  Future<Response> purgeItemWithHttpInfo(
    String itemId, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/trash/{item_id}'.replaceAll('{item_id}', itemId);

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

  /// Purge Item
  ///
  /// Delete an item in Recently deleted for good now, with its earlier versions; it cannot be brought back or undone. Copies in the host's snapshots stay until those expire (backups_kept_until).
  ///
  /// Parameters:
  ///
  /// * [String] itemId (required):
  Future<void> purgeItem(
    String itemId, {
    Future<void>? abortTrigger,
  }) async {
    final response = await purgeItemWithHttpInfo(
      itemId,
      abortTrigger: abortTrigger,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Remove Account
  ///
  /// Unlink an account: its mirrored contacts and calendars and its Keychain item are deleted. Copies in the host's snapshots stay until they expire (within 12 months while the host runs). Nothing changes at the provider. With no account left the host returns to demo mode.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] accountId (required):
  Future<Response> removeAccountWithHttpInfo(
    String accountId, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path =
        r'/accounts/{account_id}'.replaceAll('{account_id}', accountId);

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

  /// Remove Account
  ///
  /// Unlink an account: its mirrored contacts and calendars and its Keychain item are deleted. Copies in the host's snapshots stay until they expire (within 12 months while the host runs). Nothing changes at the provider. With no account left the host returns to demo mode.
  ///
  /// Parameters:
  ///
  /// * [String] accountId (required):
  Future<AccountOut?> removeAccount(
    String accountId, {
    Future<void>? abortTrigger,
  }) async {
    final response = await removeAccountWithHttpInfo(
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
        'AccountOut',
      ) as AccountOut;
    }
    return null;
  }

  /// Request Mac Access
  ///
  /// Show the system's permission prompt for contacts or calendars. Only call this when the user pressed Allow. Waits for the answer (up to a few minutes) and returns the source with the new status.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [AccessIn] accessIn (required):
  Future<Response> requestMacAccessWithHttpInfo(
    AccessIn accessIn, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/sources/mac/request-access';

    // ignore: prefer_final_locals
    Object? postBody = accessIn;

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

  /// Request Mac Access
  ///
  /// Show the system's permission prompt for contacts or calendars. Only call this when the user pressed Allow. Waits for the answer (up to a few minutes) and returns the source with the new status.
  ///
  /// Parameters:
  ///
  /// * [AccessIn] accessIn (required):
  Future<SourceOut?> requestMacAccess(
    AccessIn accessIn, {
    Future<void>? abortTrigger,
  }) async {
    final response = await requestMacAccessWithHttpInfo(
      accessIn,
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
        'SourceOut',
      ) as SourceOut;
    }
    return null;
  }

  /// Restore Item
  ///
  /// Bring an item back from Recently deleted. 404 when it is not there (or was deleted for good).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] itemId (required):
  Future<Response> restoreItemWithHttpInfo(
    String itemId, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/trash/{item_id}/restore'.replaceAll('{item_id}', itemId);

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

  /// Restore Item
  ///
  /// Bring an item back from Recently deleted. 404 when it is not there (or was deleted for good).
  ///
  /// Parameters:
  ///
  /// * [String] itemId (required):
  Future<ContactWriteOut?> restoreItem(
    String itemId, {
    Future<void>? abortTrigger,
  }) async {
    final response = await restoreItemWithHttpInfo(
      itemId,
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
        'ContactWriteOut',
      ) as ContactWriteOut;
    }
    return null;
  }

  /// Set Mac Reader
  ///
  /// Where the myData app's reader helper is (myData.app/Contents/Helpers/myDataReader.app). The myData app sends this at start; the host checks it is the reader before using it.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [ReaderIn] readerIn (required):
  Future<Response> setMacReaderWithHttpInfo(
    ReaderIn readerIn, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/sources/mac/reader';

    // ignore: prefer_final_locals
    Object? postBody = readerIn;

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

  /// Set Mac Reader
  ///
  /// Where the myData app's reader helper is (myData.app/Contents/Helpers/myDataReader.app). The myData app sends this at start; the host checks it is the reader before using it.
  ///
  /// Parameters:
  ///
  /// * [ReaderIn] readerIn (required):
  Future<SourceOut?> setMacReader(
    ReaderIn readerIn, {
    Future<void>? abortTrigger,
  }) async {
    final response = await setMacReaderWithHttpInfo(
      readerIn,
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
        'SourceOut',
      ) as SourceOut;
    }
    return null;
  }

  /// Sources
  ///
  /// Every source: This Mac first (only on a Mac host), then each linked iCloud account.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> sourcesWithHttpInfo({
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/sources';

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

  /// Sources
  ///
  /// Every source: This Mac first (only on a Mac host), then each linked iCloud account.
  Future<SourcesOut?> sources({
    Future<void>? abortTrigger,
  }) async {
    final response = await sourcesWithHttpInfo(
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
        'SourcesOut',
      ) as SourcesOut;
    }
    return null;
  }

  /// Sync Account
  ///
  /// Sync now: the account is synced next, in the background. Follow it with GET /sync.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] accountId (required):
  Future<Response> syncAccountWithHttpInfo(
    String accountId, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path =
        r'/accounts/{account_id}/sync'.replaceAll('{account_id}', accountId);

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

  /// Sync Account
  ///
  /// Sync now: the account is synced next, in the background. Follow it with GET /sync.
  ///
  /// Parameters:
  ///
  /// * [String] accountId (required):
  Future<AccountSyncOut?> syncAccount(
    String accountId, {
    Future<void>? abortTrigger,
  }) async {
    final response = await syncAccountWithHttpInfo(
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
        'AccountSyncOut',
      ) as AccountSyncOut;
    }
    return null;
  }

  /// Sync Mac
  ///
  /// Read the Mac's contacts and calendars again now, in the background.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> syncMacWithHttpInfo({
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/sources/mac/sync';

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

  /// Sync Mac
  ///
  /// Read the Mac's contacts and calendars again now, in the background.
  Future<SourceOut?> syncMac({
    Future<void>? abortTrigger,
  }) async {
    final response = await syncMacWithHttpInfo(
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
        'SourceOut',
      ) as SourceOut;
    }
    return null;
  }

  /// Sync Status
  ///
  /// The mode, and each account's sync status.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> syncStatusWithHttpInfo({
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/sync';

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

  /// Sync Status
  ///
  /// The mode, and each account's sync status.
  Future<SyncOut?> syncStatus({
    Future<void>? abortTrigger,
  }) async {
    final response = await syncStatusWithHttpInfo(
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
        'SyncOut',
      ) as SyncOut;
    }
    return null;
  }

  /// Trash
  ///
  /// Recently deleted: what was deleted in the apps, the most recent first, with when each is deleted for good. Copies in the host's snapshots stay until those expire.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] kind:
  ///   what to list
  Future<Response> trashWithHttpInfo({
    String? kind,
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/trash';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (kind != null) {
      queryParams.addAll(_queryParams('', 'kind', kind));
    }

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

  /// Trash
  ///
  /// Recently deleted: what was deleted in the apps, the most recent first, with when each is deleted for good. Copies in the host's snapshots stay until those expire.
  ///
  /// Parameters:
  ///
  /// * [String] kind:
  ///   what to list
  Future<List<TrashItemOut>?> trash({
    String? kind,
    Future<void>? abortTrigger,
  }) async {
    final response = await trashWithHttpInfo(
      kind: kind,
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
      return (await apiClient.deserializeAsync(
              responseBody, 'List<TrashItemOut>') as List)
          .cast<TrashItemOut>()
          .toList(growable: false);
    }
    return null;
  }

  /// Undo
  ///
  /// Undo one change by its undo id. The undo is a new change: it is refused when the item changed since (nothing later is ever overwritten), and a change is undone at most once, also across a restart.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] undoId (required):
  Future<Response> undoWithHttpInfo(
    String undoId, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/undo/{undo_id}'.replaceAll('{undo_id}', undoId);

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

  /// Undo
  ///
  /// Undo one change by its undo id. The undo is a new change: it is refused when the item changed since (nothing later is ever overwritten), and a change is undone at most once, also across a restart.
  ///
  /// Parameters:
  ///
  /// * [String] undoId (required):
  Future<UndoOut?> undo(
    String undoId, {
    Future<void>? abortTrigger,
  }) async {
    final response = await undoWithHttpInfo(
      undoId,
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
        'UndoOut',
      ) as UndoOut;
    }
    return null;
  }

  /// Update Contact
  ///
  /// Change an owned contact. Only the fields in the body change (null clears one), and of the card only the lines whose values change are written. Refused with 412 when the contact changed since its etag.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] contactId (required):
  ///
  /// * [ContactIn] contactIn (required):
  ///
  /// * [String] ifMatch:
  ///   the etag the change was made from
  Future<Response> updateContactWithHttpInfo(
    String contactId,
    ContactIn contactIn, {
    String? ifMatch,
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path =
        r'/contacts/{contact_id}'.replaceAll('{contact_id}', contactId);

    // ignore: prefer_final_locals
    Object? postBody = contactIn;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (ifMatch != null) {
      headerParams[r'If-Match'] = parameterToString(ifMatch);
    }

    const contentTypes = <String>['application/json'];

    return apiClient.invokeAPI(
      path,
      'PATCH',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Update Contact
  ///
  /// Change an owned contact. Only the fields in the body change (null clears one), and of the card only the lines whose values change are written. Refused with 412 when the contact changed since its etag.
  ///
  /// Parameters:
  ///
  /// * [String] contactId (required):
  ///
  /// * [ContactIn] contactIn (required):
  ///
  /// * [String] ifMatch:
  ///   the etag the change was made from
  Future<ContactWriteOut?> updateContact(
    String contactId,
    ContactIn contactIn, {
    String? ifMatch,
    Future<void>? abortTrigger,
  }) async {
    final response = await updateContactWithHttpInfo(
      contactId,
      contactIn,
      ifMatch: ifMatch,
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
        'ContactWriteOut',
      ) as ContactWriteOut;
    }
    return null;
  }
}
