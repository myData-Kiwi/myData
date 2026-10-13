# mydata_client.model.EventOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**allDay** | **bool** |  | 
**calendarId** | **String** |  | 
**end** | **String** | as start; an all-day event's end is the day after its last day (exclusive) | 
**eventId** | **String** |  | 
**location** | **String** |  | [optional] [default to '']
**notes** | **String** |  | [optional] [default to '']
**recurrenceId** | **String** |  | [optional] 
**start** | **String** | ISO date-time in the host's time zone, or YYYY-MM-DD for an all-day event | 
**timeZone** | **String** | the event's own zone; none for all-day events | [optional] 
**title** | **String** |  | 
**uid** | **String** |  | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


