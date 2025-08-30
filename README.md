# rfq-insights

rules_version = '2';
service cloud.firestore {
match /databases/{database}/documents {
// This rule allows anyone to read all documents
// match /{document=\*\*} {
// allow read: if true;
// }
// Master lists: All authenticated users can read, but only admins can write.
match /{list} {
allow read: if request.auth != null;
allow write: if request.auth != null && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == false;
}

    // Master lists can be read by any authenticated user, but only admins can edit them
    match /{listName} {
      allow read: if request.auth != null;
      allow write: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }
    // RFQ records: A user can only read/write their own RFQs, unless they are an admin.
    match /rfqs/{rfqId} {
      allow read: if request.auth != null && (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true || request.auth.uid == resource.data.userId);

      allow create: if request.auth != null && request.auth.uid == request.resource.data.userId;

      allow update: if request.auth != null && request.auth.uid == resource.data.userId;

      allow delete: if request.auth != null && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }

}
}
