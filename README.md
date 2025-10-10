# WaypointWheels iOS

## Health check
The home screen shows the API health status by calling the `/health` endpoint of the backend. The base URL is read from the **API_BASE_URL** entry under **Info → Custom iOS Target Properties** in the Xcode project. Update that value to point the app at a different backend and rebuild to see the health status for the new environment.
