# QA Checklist

## Auth

- Sign in with a valid email.
- Confirm sign out returns to auth screen.

## Room list and membership

- Create room from plus button.
- Join room using a valid 4-digit code.
- Verify rooms list only contains joined rooms.

## In-room voice

- Join room detail and connect audio.
- Confirm microphone permission prompt appears on first use.
- Mute and unmute toggles update UI.
- Leave voice room disconnects audio.

## Room admin

- Owner can remove a member.
- Owner can delete room.
- Non-owner cannot delete room.

## Invite flow

- Share room link.
- Join using copied 4-digit code.

## Backend safety

- Token function rejects unauthenticated requests.
- Token function rejects non-members.
- RLS prevents non-members from reading room data.
