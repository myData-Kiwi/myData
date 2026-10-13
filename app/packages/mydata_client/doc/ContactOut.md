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
**caption** | **String** | the line under the name in the contact list: the organisation, else the first email or phone that is not already the name; none when there is nothing else to say | [optional] 
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
**sortLetter** | **String** | the contact list's letter group: the first letter of display_name without accents, upper case; \"#\" when it does not start with a letter (digits, symbols, Chinese, Japanese kanji or Korean characters) | 
**source_** | **String** | where the contact comes from | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


