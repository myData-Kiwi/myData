# mydata_client.model.CalendarOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**accountCaption** | **String** | This Mac only: the account the calendar belongs to on the Mac, as macOS names it (\"iCloud\", \"Google\", \"Exchange\"), or \"Only on this Mac\", \"Birthdays from Contacts\", \"Subscribed\". None for an iCloud account's calendars, and when the Mac names no account | [optional] 
**accountId** | **String** |  | 
**color** | **String** | #RRGGBB as the source gives it (any alpha dropped); none when the calendar has no colour | [optional] 
**id** | **String** |  | 
**name** | **String** |  | 
**source_** | **String** | the source the calendar is read through | 
**sourceLabel** | **String** | the source as the calendar list heads its group: \"This Mac\" or \"iCloud account <email>\" | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


