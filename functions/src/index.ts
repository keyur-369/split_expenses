/**
 * Split Expenses — Firebase Cloud Functions
 *
 * Triggers:
 *  1. onMemberAdded    → notifies a user when they are added to a group
 *  2. onExpenseCreated → notifies all split members (except the payer) about a new expense
 *  3. onPaymentMarked  → notifies the debtor when their payment is marked as paid
 */

import * as admin from "firebase-admin";
import {
    onDocumentUpdated,
    onDocumentCreated,
} from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ─────────────────────────────────────────────────────────────────────────────
// Helper: fetch an FCM token for a given userId
// ─────────────────────────────────────────────────────────────────────────────
async function getFcmToken(userId: string): Promise<string | null> {
    try {
        const doc = await db.collection("users").doc(userId).get();
        if (!doc.exists) return null;
        const token = (doc.data() as Record<string, unknown>)?.fcmToken;
        return typeof token === "string" && token.length > 0 ? token : null;
    } catch (e) {
        logger.error(`Error fetching FCM token for ${userId}:`, e);
        return null;
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: fetch user's display name
// ─────────────────────────────────────────────────────────────────────────────
async function getUserName(userId: string): Promise<string> {
    try {
        const doc = await db.collection("users").doc(userId).get();
        if (!doc.exists) return "Someone";
        const name = (doc.data() as Record<string, unknown>)?.name;
        return typeof name === "string" && name.length > 0 ? name : "Someone";
    } catch (_) {
        return "Someone";
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: send a single FCM notification safely
// ─────────────────────────────────────────────────────────────────────────────
async function sendNotification(
    token: string,
    title: string,
    body: string,
    data?: Record<string, string>
): Promise<void> {
    try {
        await messaging.send({
            token,
            notification: { title, body },
            data: data ?? {},
            android: {
                notification: {
                    channelId: "split_expenses_high",
                    priority: "high",
                    sound: "default",
                },
                priority: "high",
            },
            apns: {
                payload: {
                    aps: {
                        sound: "default",
                        badge: 1,
                    },
                },
            },
        });
        logger.info(`✅ Notification sent → "${title}"`);
    } catch (e: unknown) {
        // If the token is invalid/expired, log but don't crash
        const msg = e instanceof Error ? e.message : String(e);
        if (
            msg.includes("registration-token-not-registered") ||
            msg.includes("invalid-argument")
        ) {
            logger.warn(`⚠️  Stale FCM token removed for notification: ${title}`);
        } else {
            logger.error(`❌ Failed to send notification: ${msg}`);
        }
    }
}

// =============================================================================
// TRIGGER 1: Member Added to Group
// Fires when a group document's `members` array grows — notifies the new users.
// =============================================================================
export const onMemberAdded = onDocumentUpdated(
    "groups/{groupId}",
    async (event) => {
        const before = event.data?.before.data() as
            | Record<string, unknown>
            | undefined;
        const after = event.data?.after.data() as
            | Record<string, unknown>
            | undefined;

        if (!before || !after) return;

        const membersBefore = (before.members as string[]) ?? [];
        const membersAfter = (after.members as string[]) ?? [];
        const groupName = (after.name as string) ?? "a group";
        const ownerId = (after.ownerId as string) ?? "";

        // Find newly added member IDs
        const newMembers = membersAfter.filter(
            (uid) => !membersBefore.includes(uid) && uid !== ownerId
        );

        if (newMembers.length === 0) return;

        logger.info(
            `👥 Group "${groupName}" — ${newMembers.length} new member(s) added`
        );

        const ownerName = await getUserName(ownerId);

        const notifications = newMembers.map(async (userId) => {
            const token = await getFcmToken(userId);
            if (!token) return;

            await sendNotification(
                token,
                "You were added to a group! 👥",
                `${ownerName} added you to the group "${groupName}"`,
                { type: "member_added", groupId: event.params.groupId }
            );
        });

        await Promise.all(notifications);
    }
);

// =============================================================================
// TRIGGER 2: New Expense Added
// Fires when a new expense document is created — notifies everyone who owes money.
// =============================================================================
export const onExpenseCreated = onDocumentCreated(
    "expenses/{expenseId}",
    async (event) => {
        const data = event.data?.data() as Record<string, unknown> | undefined;
        if (!data) return;

        const title = (data.title as string) ?? "an expense";
        const amount = (data.amount as number) ?? 0;
        const paidBy = (data.paidBy as string) ?? "";
        const splitWith = (data.splitWith as string[]) ?? [];
        const groupId = (data.groupId as string) ?? "";

        // Recipients = everyone in splitWith EXCEPT the payer (they already know)
        const recipients = splitWith.filter((uid) => uid !== paidBy);

        if (recipients.length === 0) return;

        logger.info(
            `💸 New expense "${title}" (₹${amount}) — notifying ${recipients.length} member(s)`
        );

        const payerName = await getUserName(paidBy);
        const perPerson = (amount / splitWith.length).toFixed(2);

        // Fetch group name for context
        let groupName = "the group";
        if (groupId) {
            try {
                const groupDoc = await db.collection("groups").doc(groupId).get();
                if (groupDoc.exists) {
                    groupName =
                        (groupDoc.data() as Record<string, unknown>)?.name as string ??
                        "the group";
                }
            } catch (_) { }
        }

        const notifications = recipients.map(async (userId) => {
            const token = await getFcmToken(userId);
            if (!token) return;

            await sendNotification(
                token,
                `New expense in "${groupName}" 💸`,
                `${payerName} added "${title}" for ₹${amount}. Your share: ₹${perPerson}`,
                {
                    type: "expense_added",
                    groupId,
                    expenseId: event.params.expenseId,
                }
            );
        });

        await Promise.all(notifications);
    }
);

// =============================================================================
// TRIGGER 3: Payment Marked as Paid
// Fires when a settlement document is created — notifies the debtor.
// =============================================================================
export const onPaymentMarked = onDocumentCreated(
    "groups/{groupId}/settlements/{settlementId}",
    async (event) => {
        const data = event.data?.data() as Record<string, unknown> | undefined;
        if (!data) return;

        const debtorId = (data.debtorId as string) ?? "";
        const creditorId = (data.creditorId as string) ?? "";
        const amount = (data.amount as number) ?? 0;
        const note = (data.note as string) ?? "";
        const groupId = event.params.groupId;

        if (!debtorId) return;

        logger.info(
            `✅ Payment marked — debtor: ${debtorId}, creditor: ${creditorId}, ₹${amount}`
        );

        const token = await getFcmToken(debtorId);
        if (!token) return;

        const creditorName = await getUserName(creditorId);

        // Fetch group name for context
        let groupName = "the group";
        try {
            const groupDoc = await db.collection("groups").doc(groupId).get();
            if (groupDoc.exists) {
                groupName =
                    (groupDoc.data() as Record<string, unknown>)?.name as string ??
                    "the group";
            }
        } catch (_) { }

        const body = note.trim()
            ? `${creditorName} confirmed ₹${amount} in "${groupName}". Note: ${note}`
            : `${creditorName} confirmed your payment of ₹${amount} in "${groupName}"`;

        await sendNotification(
            token,
            "Payment confirmed ✅",
            body,
            { type: "payment_confirmed", groupId, settlementId: event.params.settlementId }
        );
    }
);
