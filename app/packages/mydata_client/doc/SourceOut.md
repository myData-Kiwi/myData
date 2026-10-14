# mydata_client.model.SourceOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**allCalendars** | **bool** | This Mac: as all_contact_containers, for calendars | [optional] 
**allContactContainers** | **bool** | This Mac: true when no choice was made (every account, including ones added later); send contact_containers null to keep it so | [optional] 
**available** | **bool** |  | [optional] [default to true]
**backupsKeptUntil** | **String** | YYYY-MM-DD: if it is turned off or removed now, copies of what it mirrored stay in the host's snapshots until this day, while the host keeps running (the turn-off and remove dialogs say so) | [optional] 
**calendars** | [**List<MacCalendarOut>**](MacCalendarOut.md) |  | [optional] [default to const []]
**calendarsStatus** | **String** | This Mac: notDetermined, restricted, denied, fullAccess, writeOnly, or unknown (as contacts_status) | [optional] 
**contactContainers** | [**List<MacContainerOut>**](MacContainerOut.md) |  | [optional] [default to const []]
**contactsStatus** | **String** | This Mac: notDetermined, restricted, denied, authorized, or unknown (not reported yet, or a value this host does not know: not readable) | [optional] 
**counts** | [**SyncCounts**](SyncCounts.md) | what the source holds now: for an iCloud account, as of its last sync; for This Mac while it is on | [optional] 
**decided** | **bool** | This Mac: true once the user turned it on or off (the myData app's first-run step is then not shown) | [optional] 
**email** | **String** | iCloud: the account's email | [optional] 
**enabled** | **bool** |  | 
**id** | **String** | \"mac\" for This Mac; the account id for an iCloud account | 
**kind** | **String** |  | 
**lastError** | **String** | a short message for the user; never a secret | [optional] 
**lastUpdate** | **String** |  | [optional] 
**notesIncluded** | **bool** | false for This Mac: contact notes are never read | 
**readerRunning** | **bool** | This Mac: the reader helper is connected | [optional] 
**state** | **String** |  | [optional] 
**window** | [**WindowOut**](WindowOut.md) | This Mac: the days of events it holds | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


