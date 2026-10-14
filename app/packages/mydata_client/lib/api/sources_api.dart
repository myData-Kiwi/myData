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
  /// One contact, for its page: the fields grouped by kind, the job title and where the card comes from; whether it can be changed here, and its etag (also the ETag header). A contact in Recently deleted is 404 unless include_deleted; one that was merged says which contact it went into (merged_into).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] contactId (required):
  ///
  /// * [bool] raw:
  ///   include the raw vCard
  ///
  /// * [bool] includeDeleted:
  ///   also a contact of yours in Recently deleted (deleted_at set): a link to a merged original finds merged_into
  Future<Response> contactWithHttpInfo(
    String contactId, {
    bool? raw,
    bool? includeDeleted,
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
    if (includeDeleted != null) {
      queryParams.addAll(_queryParams('', 'include_deleted', includeDeleted));
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
  /// One contact, for its page: the fields grouped by kind, the job title and where the card comes from; whether it can be changed here, and its etag (also the ETag header). A contact in Recently deleted is 404 unless include_deleted; one that was merged says which contact it went into (merged_into).
  ///
  /// Parameters:
  ///
  /// * [String] contactId (required):
  ///
  /// * [bool] raw:
  ///   include the raw vCard
  ///
  /// * [bool] includeDeleted:
  ///   also a contact of yours in Recently deleted (deleted_at set): a link to a merged original finds merged_into
  Future<ContactDetailOut?> contact(
    String contactId, {
    bool? raw,
    bool? includeDeleted,
    Future<void>? abortTrigger,
  }) async {
    final response = await contactWithHttpInfo(
      contactId,
      raw: raw,
      includeDeleted: includeDeleted,
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
  /// Move an owned contact to Recently deleted. It is deleted for good after 30 days (purge_after); until then POST /trash/{id}/restore or the undo id brings it back. Refused with 412 when the contact changed since its etag. Copies in the host's snapshots stay until those expire (within 12 months while the host runs).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] contactId (required):
  ///
  /// * [String] ifMatch:
  ///   the etag of the contact the user chose to delete
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
  /// Move an owned contact to Recently deleted. It is deleted for good after 30 days (purge_after); until then POST /trash/{id}/restore or the undo id brings it back. Refused with 412 when the contact changed since its etag. Copies in the host's snapshots stay until those expire (within 12 months while the host runs).
  ///
  /// Parameters:
  ///
  /// * [String] contactId (required):
  ///
  /// * [String] ifMatch:
  ///   the etag of the contact the user chose to delete
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

  /// Duplicates
  ///
  /// Pairs of contacts of yours that may be one person, strong ones first, for myContacts' Review: the same email or phone under the same name is strong; the same name alone, or an email or phone shared under another name, is a suggestion. Followed contacts are never offered, and pairs marked as different people (POST /contacts/not-duplicates) are left out. Nothing is merged here.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] limit:
  Future<Response> duplicatesWithHttpInfo({
    int? limit,
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/contacts/duplicates';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (limit != null) {
      queryParams.addAll(_queryParams('', 'limit', limit));
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

  /// Duplicates
  ///
  /// Pairs of contacts of yours that may be one person, strong ones first, for myContacts' Review: the same email or phone under the same name is strong; the same name alone, or an email or phone shared under another name, is a suggestion. Followed contacts are never offered, and pairs marked as different people (POST /contacts/not-duplicates) are left out. Nothing is merged here.
  ///
  /// Parameters:
  ///
  /// * [int] limit:
  Future<List<DuplicatePairOut>?> duplicates({
    int? limit,
    Future<void>? abortTrigger,
  }) async {
    final response = await duplicatesWithHttpInfo(
      limit: limit,
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
              responseBody, 'List<DuplicatePairOut>') as List)
          .cast<DuplicatePairOut>()
          .toList(growable: false);
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

  /// Followed Changes
  ///
  /// A contact of yours beside each followed copy of it (This Mac, an iCloud account) that changed since the import (changed_in_source), with what differs: \"Changed since import\" in myContacts' Review. Settle it with .../followed-changes/save or .../keep.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] contactId (required):
  Future<Response> followedChangesWithHttpInfo(
    String contactId, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/contacts/{contact_id}/followed-changes'
        .replaceAll('{contact_id}', contactId);

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

  /// Followed Changes
  ///
  /// A contact of yours beside each followed copy of it (This Mac, an iCloud account) that changed since the import (changed_in_source), with what differs: \"Changed since import\" in myContacts' Review. Settle it with .../followed-changes/save or .../keep.
  ///
  /// Parameters:
  ///
  /// * [String] contactId (required):
  Future<FollowedChangesOut?> followedChanges(
    String contactId, {
    Future<void>? abortTrigger,
  }) async {
    final response = await followedChangesWithHttpInfo(
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
        'FollowedChangesOut',
      ) as FollowedChangesOut;
    }
    return null;
  }

  /// Keep Mine
  ///
  /// Keep your version: clear the \"changed since import\" mark of the copies reviewed, the contact unchanged. 412 when a copy changed again since it was shown; 409 for a copy with nothing to review. undo_id brings the mark back (POST /undo/{undo_id}).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] contactId (required):
  ///
  /// * [FollowedKeepIn] followedKeepIn (required):
  Future<Response> keepMineWithHttpInfo(
    String contactId,
    FollowedKeepIn followedKeepIn, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/contacts/{contact_id}/followed-changes/keep'
        .replaceAll('{contact_id}', contactId);

    // ignore: prefer_final_locals
    Object? postBody = followedKeepIn;

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

  /// Keep Mine
  ///
  /// Keep your version: clear the \"changed since import\" mark of the copies reviewed, the contact unchanged. 412 when a copy changed again since it was shown; 409 for a copy with nothing to review. undo_id brings the mark back (POST /undo/{undo_id}).
  ///
  /// Parameters:
  ///
  /// * [String] contactId (required):
  ///
  /// * [FollowedKeepIn] followedKeepIn (required):
  Future<ContactWriteOut?> keepMine(
    String contactId,
    FollowedKeepIn followedKeepIn, {
    Future<void>? abortTrigger,
  }) async {
    final response = await keepMineWithHttpInfo(
      contactId,
      followedKeepIn,
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

  /// Merge Contacts
  ///
  /// Merge owned contacts the user chose as one person (never automatic): a new contact holds the first one's names (or names_from's), every email, phone, address and link of them all, and every other property it has no value of; what it cannot take (a second job title or birthday, another photo) is listed in left_out. The originals go to Recently deleted, unchanged, so POST /undo/{undo_id} brings them back while nothing changed since. 412 when a contact changed since its etag.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [MergeIn] mergeIn (required):
  Future<Response> mergeContactsWithHttpInfo(
    MergeIn mergeIn, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/contacts/merge';

    // ignore: prefer_final_locals
    Object? postBody = mergeIn;

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

  /// Merge Contacts
  ///
  /// Merge owned contacts the user chose as one person (never automatic): a new contact holds the first one's names (or names_from's), every email, phone, address and link of them all, and every other property it has no value of; what it cannot take (a second job title or birthday, another photo) is listed in left_out. The originals go to Recently deleted, unchanged, so POST /undo/{undo_id} brings them back while nothing changed since. 412 when a contact changed since its etag.
  ///
  /// Parameters:
  ///
  /// * [MergeIn] mergeIn (required):
  Future<MergeOut?> mergeContacts(
    MergeIn mergeIn, {
    Future<void>? abortTrigger,
  }) async {
    final response = await mergeContactsWithHttpInfo(
      mergeIn,
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
        'MergeOut',
      ) as MergeOut;
    }
    return null;
  }

  /// Merge Preview
  ///
  /// What POST /contacts/merge would make of these contacts now, written nowhere: the merged contact (the \"After merging\" column) and each value it would leave out, with the value and whose it is, so the user sees what is kept and left out before pressing Merge. Read it again when names_from changes. The same refusals as a merge: 412 when a contact changed since its etag.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [MergeIn] mergeIn (required):
  Future<Response> mergePreviewWithHttpInfo(
    MergeIn mergeIn, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/contacts/merge/preview';

    // ignore: prefer_final_locals
    Object? postBody = mergeIn;

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

  /// Merge Preview
  ///
  /// What POST /contacts/merge would make of these contacts now, written nowhere: the merged contact (the \"After merging\" column) and each value it would leave out, with the value and whose it is, so the user sees what is kept and left out before pressing Merge. Read it again when names_from changes. The same refusals as a merge: 412 when a contact changed since its etag.
  ///
  /// Parameters:
  ///
  /// * [MergeIn] mergeIn (required):
  Future<MergePreviewOut?> mergePreview(
    MergeIn mergeIn, {
    Future<void>? abortTrigger,
  }) async {
    final response = await mergePreviewWithHttpInfo(
      mergeIn,
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
        'MergePreviewOut',
      ) as MergePreviewOut;
    }
    return null;
  }

  /// Not Duplicates
  ///
  /// \"Not the same person\": the two contacts of yours are never offered as possible duplicates again (GET /contacts/duplicates), also after an import or a merge, until undone with POST /undo/{undo_id}. Nothing on either contact changes.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [NotDuplicatesIn] notDuplicatesIn (required):
  Future<Response> notDuplicatesWithHttpInfo(
    NotDuplicatesIn notDuplicatesIn, {
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/contacts/not-duplicates';

    // ignore: prefer_final_locals
    Object? postBody = notDuplicatesIn;

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

  /// Not Duplicates
  ///
  /// \"Not the same person\": the two contacts of yours are never offered as possible duplicates again (GET /contacts/duplicates), also after an import or a merge, until undone with POST /undo/{undo_id}. Nothing on either contact changes.
  ///
  /// Parameters:
  ///
  /// * [NotDuplicatesIn] notDuplicatesIn (required):
  Future<NotDuplicatesOut?> notDuplicates(
    NotDuplicatesIn notDuplicatesIn, {
    Future<void>? abortTrigger,
  }) async {
    final response = await notDuplicatesWithHttpInfo(
      notDuplicatesIn,
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
        'NotDuplicatesOut',
      ) as NotDuplicatesOut;
    }
    return null;
  }

  /// Purge Item
  ///
  /// Delete an item in Recently deleted for good now, with its earlier versions; it cannot be brought back or undone. Refused with 412 when the item changed since its etag (restored, changed and deleted again elsewhere): look at it again first. The host log records which app asked. Copies in the host's snapshots stay until those expire (backups_kept_until).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] itemId (required):
  ///
  /// * [String] ifMatch:
  ///   the item's etag as Recently deleted lists it (contact.etag)
  Future<Response> purgeItemWithHttpInfo(
    String itemId, {
    String? ifMatch,
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/trash/{item_id}'.replaceAll('{item_id}', itemId);

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

  /// Purge Item
  ///
  /// Delete an item in Recently deleted for good now, with its earlier versions; it cannot be brought back or undone. Refused with 412 when the item changed since its etag (restored, changed and deleted again elsewhere): look at it again first. The host log records which app asked. Copies in the host's snapshots stay until those expire (backups_kept_until).
  ///
  /// Parameters:
  ///
  /// * [String] itemId (required):
  ///
  /// * [String] ifMatch:
  ///   the item's etag as Recently deleted lists it (contact.etag)
  Future<void> purgeItem(
    String itemId, {
    String? ifMatch,
    Future<void>? abortTrigger,
  }) async {
    final response = await purgeItemWithHttpInfo(
      itemId,
      ifMatch: ifMatch,
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
  /// Bring an item back from Recently deleted. 404 when it is not there (or was deleted for good); 412 when If-Match is sent and the item changed since.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] itemId (required):
  ///
  /// * [String] ifMatch:
  ///   optional: the item's etag as Recently deleted lists it; refuse if it changed since
  Future<Response> restoreItemWithHttpInfo(
    String itemId, {
    String? ifMatch,
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/trash/{item_id}/restore'.replaceAll('{item_id}', itemId);

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
  /// Bring an item back from Recently deleted. 404 when it is not there (or was deleted for good); 412 when If-Match is sent and the item changed since.
  ///
  /// Parameters:
  ///
  /// * [String] itemId (required):
  ///
  /// * [String] ifMatch:
  ///   optional: the item's etag as Recently deleted lists it; refuse if it changed since
  Future<ContactWriteOut?> restoreItem(
    String itemId, {
    String? ifMatch,
    Future<void>? abortTrigger,
  }) async {
    final response = await restoreItemWithHttpInfo(
      itemId,
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

  /// Save Followed Changes
  ///
  /// Save the values the user chose (the \"After\" column) into the contact of yours, as an edit (only the lines whose values change), and clear the \"changed since import\" mark of the copies reviewed until they change again. 412 when the contact, or a copy, changed since it was shown; 409 for a copy with nothing to review. undo_id undoes both (POST /undo/{undo_id}) while the contact is unchanged since.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] contactId (required):
  ///
  /// * [FollowedSaveIn] followedSaveIn (required):
  ///
  /// * [String] ifMatch:
  ///   the contact's etag, as shown beside its copies
  Future<Response> saveFollowedChangesWithHttpInfo(
    String contactId,
    FollowedSaveIn followedSaveIn, {
    String? ifMatch,
    Future<void>? abortTrigger,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/contacts/{contact_id}/followed-changes/save'
        .replaceAll('{contact_id}', contactId);

    // ignore: prefer_final_locals
    Object? postBody = followedSaveIn;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (ifMatch != null) {
      headerParams[r'If-Match'] = parameterToString(ifMatch);
    }

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

  /// Save Followed Changes
  ///
  /// Save the values the user chose (the \"After\" column) into the contact of yours, as an edit (only the lines whose values change), and clear the \"changed since import\" mark of the copies reviewed until they change again. 412 when the contact, or a copy, changed since it was shown; 409 for a copy with nothing to review. undo_id undoes both (POST /undo/{undo_id}) while the contact is unchanged since.
  ///
  /// Parameters:
  ///
  /// * [String] contactId (required):
  ///
  /// * [FollowedSaveIn] followedSaveIn (required):
  ///
  /// * [String] ifMatch:
  ///   the contact's etag, as shown beside its copies
  Future<ContactWriteOut?> saveFollowedChanges(
    String contactId,
    FollowedSaveIn followedSaveIn, {
    String? ifMatch,
    Future<void>? abortTrigger,
  }) async {
    final response = await saveFollowedChangesWithHttpInfo(
      contactId,
      followedSaveIn,
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
  /// Undo one change by its undo id, a merge's too. The undo is a new change: it is refused when the item changed since (nothing later is ever overwritten), and a change is undone at most once, also across a restart. Undoing a merge restores each original and moves the merged contact to Recently deleted.
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
  /// Undo one change by its undo id, a merge's too. The undo is a new change: it is refused when the item changed since (nothing later is ever overwritten), and a change is undone at most once, also across a restart. Undoing a merge restores each original and moves the merged contact to Recently deleted.
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
