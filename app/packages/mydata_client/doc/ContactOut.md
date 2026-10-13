# mydata_client.model.ContactOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**accountId** | **String** |  | 
**addressBookId** | **String** |  | 
**addresses** | [**List<PostalAddress>**](PostalAddress.md) |  | [optional] [default to const []]
**birthday** | **String** |  | [optional] 
**createdAt** | **String** |  | 
**deletedAt** | **String** |  | [optional] 
**displayName** | **String** | the name to show: never empty (organisation, email or phone when the card has no name) | 
**emails** | [**List<LabeledValue>**](LabeledValue.md) |  | [optional] [default to const []]
**familyName** | **String** |  | [optional] [default to '']
**fullName** | **String** |  | [optional] [default to '']
**givenName** | **String** |  | [optional] [default to '']
**hasPhoto** | **bool** |  | [optional] [default to false]
**id** | **String** |  | 
**modifiedAt** | **String** |  | 
**nickname** | **String** |  | [optional] [default to '']
**note** | **String** |  | [optional] [default to '']
**notesIncluded** | **bool** | false when the source never reads notes (This Mac): show no Notes field | [optional] [default to true]
**organisation** | **String** |  | [optional] [default to '']
**phones** | [**List<LabeledValue>**](LabeledValue.md) |  | [optional] [default to const []]
**source_** | **String** | where the contact comes from | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


