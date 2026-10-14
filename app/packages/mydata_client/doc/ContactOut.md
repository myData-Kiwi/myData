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
**changedInSource** | **String** | for a contact the host owns that was imported from a followed account: that account's id (GET /sources) when its copy changed since the import (\"changed in <source> since import\", to review); null otherwise | [optional] 
**createdAt** | **String** |  | 
**deletedAt** | **String** |  | [optional] 
**displayName** | **String** | the name to show: never empty (organisation, email or phone when the card has no name) | 
**editable** | **bool** | true for a contact the host owns, which the apps may change and delete; false for one followed from a source (change it there) | 
**emails** | [**List<LabeledValue>**](LabeledValue.md) |  | [optional] [default to const []]
**etag** | **String** | the contact's current version, to send back as If-Match when changing it; it changes with every change, a delete or restore included | 
**familyName** | **String** |  | [optional] [default to '']
**fullName** | **String** |  | [optional] [default to '']
**givenName** | **String** |  | [optional] [default to '']
**hasPhoto** | **bool** |  | [optional] [default to false]
**id** | **String** |  | 
**mergedInto** | **String** | for a contact in Recently deleted because it was merged: the contact it went into, which a link to it can open instead; null otherwise | [optional] 
**modifiedAt** | **String** |  | 
**nickname** | **String** |  | [optional] [default to '']
**note** | **String** |  | [optional] [default to '']
**notesIncluded** | **bool** | false when the source never reads notes (This Mac): show no Notes field | [optional] [default to true]
**onPhone** | **bool** | false for a contact the host owns: it is on myData only, not on any phone yet. Null for a followed one (the source decides where it is) | [optional] 
**organisation** | **String** |  | [optional] [default to '']
**phones** | [**List<LabeledValue>**](LabeledValue.md) |  | [optional] [default to const []]
**purgeAfter** | **String** | for a contact in Recently deleted: when it is deleted for good (UTC) | [optional] 
**sortLetter** | **String** | the contact list's letter group: the first letter of display_name without accents, upper case; \"#\" when it does not start with a letter (digits, symbols, Chinese, Japanese kanji or Korean characters) | 
**source_** | **String** | where the contact comes from: mydata for a contact the host owns (made in an app; the only copy is on this host) | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


