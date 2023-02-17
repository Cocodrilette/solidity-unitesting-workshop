export function getTxIdFromEvents(events: any) {
  return events
    ?.map((e: any) => e.args)
    .filter((arg: any) => arg?.txId)
    .map((t: any) => t?.txId)[0];
}
