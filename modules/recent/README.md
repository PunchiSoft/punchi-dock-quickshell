# Recent applications module

`RecentApplicationsPopup` is the container item the dock shows instead of the
resolved recent rows: it anchors to that icon, confines the KWin blur to its
surface and returns the focus to the item when it closes.
`RecentApplicationsContent` draws the same selection the dock filters by pinned
and open applications, using the container Grid, List, Detail and Fan
presentations that live in `components/`. The content reports an activation; the
dock owns the launch service, so no row reaches an adapter.
