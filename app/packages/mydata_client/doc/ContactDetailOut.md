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
**changedInSource** | **String** | for a contact the host owns that was imported from a followed account: that account's id (GET /sources) when its copy changed since the import (\"changed in <source> since import\", to review); null otherwise | [optional] 
**changedInSourceLabel** | **String** | with changed_in_source: that source inside a sentence (\"the iCloud account you@example.com\") | [optional] 
**company** | **String** | the organisation's name alone (organisation also has the department, after a comma) | [optional] [default to '']
**createdAt** | **String** |  | 
**deletedAt** | **String** |  | [optional] 
**department** | **String** |  | [optional] [default to '']
**displayName** | **String** | the name to show: never empty (organisation, email or phone when the card has no name) | 
**editable** | **bool** | true for a contact the host owns, which the apps may change and delete; false for one followed from a source (change it there) | 
**emails** | [**List<LabeledValue>**](LabeledValue.md) |  | [optional] [default to const []]
**etag** | **String** | the contact's current version, to send back as If-Match when changing it; it changes with every change, a delete or restore included | 
**familyName** | **String** |  | [optional] [default to '']
**fields** | [**List<ContactFieldGroup>**](ContactFieldGroup.md) | the contact's values for its page, grouped by kind in this order: phone, email, address, birthday, url, note. A kind with no values is left out; note only when the source reads notes and the note is not empty (never for This Mac) | [default to const []]
**fullName** | **String** |  | [optional] [default to '']
**givenName** | **String** |  | [optional] [default to '']
**hasPhoto** | **bool** |  | [optional] [default to false]
**id** | **String** |  | 
**jobTitle** | **String** |  | [optional] [default to '']
**middleName** | **String** | for the edit form, as are the four fields below | [optional] [default to '']
**modifiedAt** | **String** |  | 
**namePrefix** | **String** |  | [optional] [default to '']
**nameSuffix** | **String** |  | [optional] [default to '']
**nickname** | **String** |  | [optional] [default to '']
**note** | **String** |  | [optional] [default to '']
**notesIncluded** | **bool** | false when the source never reads notes (This Mac): show no Notes field | [optional] [default to true]
**onPhone** | **bool** | false for a contact the host owns: it is on myData only, not on any phone yet. Null for a followed one (the source decides where it is) | [optional] 
**organisation** | **String** |  | [optional] [default to '']
**phones** | [**List<LabeledValue>**](LabeledValue.md) |  | [optional] [default to const []]
**purgeAfter** | **String** | for a contact in Recently deleted: when it is deleted for good (UTC) | [optional] 
**rawVcard** | **String** | the card as the server sent it; only with ?raw=1 | [optional] 
**sortLetter** | **String** | the contact list's letter group: the first letter of display_name without accents, upper case; \"#\" when it does not start with a letter (digits, symbols, Chinese, Japanese kanji or Korean characters) | 
**source_** | **String** | where the contact comes from: mydata for a contact the host owns (made in an app; the only copy is on this host) | 
**sourceLabel** | **String** | the source inside a sentence: \"this Mac\", \"the iCloud account <email>\" (\"From this Mac. Change it in Contacts.\") or \"myData\" for a contact the host owns | 
**urls** | [**List<LabeledValue>**](LabeledValue.md) | web addresses as the source wrote them; never trusted to say what they open | [optional] [default to const []]

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


