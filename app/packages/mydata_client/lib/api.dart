//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

library openapi.api;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

part 'api_client.dart';
part 'api_helper.dart';
part 'api_exception.dart';
part 'auth/authentication.dart';
part 'auth/api_key_auth.dart';
part 'auth/oauth.dart';
part 'auth/http_basic_auth.dart';
part 'auth/http_bearer_auth.dart';

part 'api/agents_api.dart';
part 'api/appearance_api.dart';
part 'api/approvals_api.dart';
part 'api/assistant_api.dart';
part 'api/host_api.dart';
part 'api/tools_api.dart';

part 'model/agent_created.dart';
part 'model/agent_in.dart';
part 'model/agent_out.dart';
part 'model/appearance_in.dart';
part 'model/appearance_out.dart';
part 'model/approval_out.dart';
part 'model/assistant_settings_in.dart';
part 'model/decision_in.dart';
part 'model/error_out.dart';
part 'model/guard_error.dart';
part 'model/http_validation_error.dart';
part 'model/memory_out.dart';
part 'model/message_in.dart';
part 'model/model_out.dart';
part 'model/progress.dart';
part 'model/status_out.dart';
part 'model/theme_out.dart';
part 'model/tool_out.dart';
part 'model/validation_error.dart';

/// An [ApiClient] instance that uses the default values obtained from
/// the OpenAPI specification file.
var defaultApiClient = ApiClient();

const _delimiters = {'csv': ',', 'ssv': ' ', 'tsv': '\t', 'pipes': '|'};
const _dateEpochMarker = 'epoch';
const _deepEquality = DeepCollectionEquality();
final _dateFormatter = DateFormat('yyyy-MM-dd');
final _regList = RegExp(r'^List<(.*)>$');
final _regSet = RegExp(r'^Set<(.*)>$');
final _regMap = RegExp(r'^Map<String,(.*)>$');

bool _isEpochMarker(String? pattern) =>
    pattern == _dateEpochMarker || pattern == '/$_dateEpochMarker/';
