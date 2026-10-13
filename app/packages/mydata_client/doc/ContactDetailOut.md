# mydata_client.model.ContactDetailOut

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
**fields** | [**List<ContactFieldGroup>**](ContactFieldGroup.md) | the contact's values for its page, grouped by kind in this order: phone, email, address, birthday, url, note. A kind with no values is left out; note only when the source reads notes and the note is not empty (never for This Mac) | [default to const []]
**fullName** | **String** |  | [optional] [default to '']
**givenName** | **String** |  | [optional] [default to '']
**hasPhoto** | **bool** |  | [optional] [default to false]
**id** | **String** |  | 
**jobTitle** | **String** |  | [optional] [default to '']
**modifiedAt** | **String** |  | 
**nickname** | **String** |  | [optional] [default to '']
**note** | **String** |  | [optional] [default to '']
**notesIncluded** | **bool** | false when the source never reads notes (This Mac): show no Notes field | [optional] [default to true]
**organisation** | **String** |  | [optional] [default to '']
**phones** | [**List<LabeledValue>**](LabeledValue.md) |  | [optional] [default to const []]
**rawVcard** | **String** | the card as the server sent it; only with ?raw=1 | [optional] 
**sortLetter** | **String** | the contact list's letter group: the first letter of display_name without accents, upper case; \"#\" when it does not start with a letter (digits, symbols, Chinese, Japanese kanji or Korean characters) | 
**source_** | **String** | where the contact comes from | 
**sourceLabel** | **String** | the source inside a sentence: \"this Mac\" or \"the iCloud account <email>\" (\"From this Mac. Change it in Contacts.\") | 
**urls** | [**List<LabeledValue>**](LabeledValue.md) | web addresses as the source wrote them; never trusted to say what they open | [optional] [default to const []]

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


