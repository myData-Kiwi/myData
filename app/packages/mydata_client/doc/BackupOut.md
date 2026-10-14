# mydata_client.model.BackupOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**error** | **String** | why the last hourly snapshot failed; null once one succeeds | [optional] 
**filevault** | **String** | whether the disk is encrypted (macOS FileVault); unknown on other systems | 
**lastSnapshotAt** | **String** | when the newest snapshot of the databases was taken (UTC); none yet: null | [optional] 
**lastVerifiedAt** | **String** | when a snapshot was last restored into a temporary folder and checked (`mydata backup verify`) | [optional] 
**lastVerifyOk** | **bool** | whether that restore drill passed | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


