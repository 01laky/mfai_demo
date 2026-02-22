# Implementation Guide: Display Detailed Device Integrity Information

## Overview

Extend the integrity check system from binary (trusted/untrusted) to store and display detailed attributes from Google Play Integrity API (Android) and Apple App Attest (iOS). Changes span 4 layers: Token Service, Repository Service (database + logic), gRPC Proto definitions, and Dashboard.

---

## PHASE 1: Token Service — Extend Validation Results

### 1.1 Extend `AndroidIntegrityValidationResult` interface

**File:** `services/token/src/clients/GoogleApiClient.ts`  
**Lines:** 13–19

Current:
typescript
export interface AndroidIntegrityValidationResult {
    isValid: boolean;
    packageName?: string | null;
    appRecognitionVerdict?: string | null;
    deviceRecogitionVerdict?: string[] | null;
    appLicensingVerdict?: string | null;
}

Change to:
typescript
export interface AndroidIntegrityValidationResult {
    isValid: boolean;
    packageName?: string | null;
    appRecognitionVerdict?: string | null;
    deviceRecognitionVerdict?: string[] | null;  // FIX typo: was "deviceRecogitionVerdict"
    appLicensingVerdict?: string | null;
    requestTimestamp?: string | null;
}

> **NOTE:** The existing field name has a typo (`deviceRecogitionVerdict` → `deviceRecognitionVerdict`). Fix this typo across the entire codebase (search for all references). The typo appears in `GoogleApiClient.ts` (interface + usage at lines 17, 91–92, 105) and in `IntegrityCheckService.ts` (referenced indirectly via the result).

### 1.2 Add `requestTimestamp` to the `validateIntegrity` return

**File:** `services/token/src/clients/GoogleApiClient.ts`  
**Lines:** 101–107

Current return:
typescript
return {
    isValid,
    packageName: requestDetails?.requestPackageName,
    appRecognitionVerdict: appIntegrity?.appRecognitionVerdict,
    deviceRecogitionVerdict: deviceIntegrity?.deviceRecognitionVerdict,
    appLicensingVerdict: accountDetails?.appLicensingVerdict,
};

Change to:
typescript
return {
    isValid,
    packageName: requestDetails?.requestPackageName,
    appRecognitionVerdict: appIntegrity?.appRecognitionVerdict,
    deviceRecognitionVerdict: deviceIntegrity?.deviceRecognitionVerdict,
    appLicensingVerdict: accountDetails?.appLicensingVerdict,
    requestTimestamp: requestDetails?.timestampMillis ?? null,
};

### 1.3 Create iOS attestation result type

**File:** `services/token/src/clients/GoogleApiClient.ts` (or create a new file `services/token/src/interfaces/IosIntegrityValidationResult.ts`)

Add:
typescript
export interface IosIntegrityValidationResult {
    isValid: boolean;
    publicKeyPem?: string | null;
    verifyError?: string | null;
}

### 1.4 Extend `UpdateTokenDto` in Token Service

**File:** `services/token/src/dtos/token/UpdateTokenDto.ts`

Current:
typescript
export type UpdateTokenDto = {
    name?: string;
    brand?: string;
    model?: string;
    systemName?: string;
    systemVersion?: string;
    appVersion?: string;
    pushId?: string;
    lastConnectedAt?: string;
    integrityStatus?: ETokenIntegrityStatus;
};

Change to:
typescript
export type UpdateTokenDto = {
    name?: string;
    brand?: string;
    model?: string;
    systemName?: string;
    systemVersion?: string;
    appVersion?: string;
    pushId?: string;
    lastConnectedAt?: string;
    integrityStatus?: ETokenIntegrityStatus;
    integrityPackageName?: string | null;
    integrityAppRecognitionVerdict?: string | null;
    integrityDeviceRecognitionVerdict?: string | null;  // JSON string of string[]
    integrityAppLicensingVerdict?: string | null;
    integrityTimestamp?: string | null;
    integrityPublicKeyPem?: string | null;
    integrityVerifyError?: string | null;
    integrityCheckedAt?: string;  // ISO 8601 string
    integrityRawResult?: string | null;  // full JSON string of the API response
};

### 1.5 Extend `TokenRepositoryClient.updateToken` to send new fields

**File:** `services/token/src/clients/repository/TokenRepositoryClient.ts`  
**Lines:** 179–211

After the existing `integrityStatus` setter (line 186), add setters for each new field:
typescript
if (tokenDto.integrityStatus) {
    request.setIntegritystatus(tokenDto.integrityStatus);
}
if (tokenDto.integrityPackageName !== undefined) {
    request.setIntegritypackagename(tokenDto.integrityPackageName ?? '');
}
if (tokenDto.integrityAppRecognitionVerdict !== undefined) {
    request.setIntegrityapprecognitionverdict(tokenDto.integrityAppRecognitionVerdict ?? '');
}
if (tokenDto.integrityDeviceRecognitionVerdict !== undefined) {
    request.setIntegritydevicerecognitionverdict(tokenDto.integrityDeviceRecognitionVerdict ?? '');
}
if (tokenDto.integrityAppLicensingVerdict !== undefined) {
    request.setIntegrityapplicensingverdict(tokenDto.integrityAppLicensingVerdict ?? '');
}
if (tokenDto.integrityTimestamp !== undefined) {
    request.setIntegritytimestamp(tokenDto.integrityTimestamp ?? '');
}
if (tokenDto.integrityPublicKeyPem !== undefined) {
    request.setIntegritypublickeypem(tokenDto.integrityPublicKeyPem ?? '');
}
if (tokenDto.integrityVerifyError !== undefined) {
    request.setIntegrityverifyerror(tokenDto.integrityVerifyError ?? '');
}
if (tokenDto.integrityCheckedAt) {
    request.setIntegritycheckedat(tokenDto.integrityCheckedAt);
}
if (tokenDto.integrityRawResult !== undefined) {
    request.setIntegrityrawresult(tokenDto.integrityRawResult ?? '');
}

### 1.6 Extend `IntegrityCheckService.validateAndroidIntegrity` to pass details

**File:** `services/token/src/services/IntegrityCheckService.ts`  
**Lines:** 219–222

Current:
typescript
await tokenRepositoryClient.updateToken(tokenID, {
    integrityStatus:
        integrityCheckResult.isValid ? ETokenIntegrityStatus.TRUSTED : ETokenIntegrityStatus.UNTRUSTED,
});

Change to:
typescript
await tokenRepositoryClient.updateToken(tokenID, {
    integrityStatus:
        integrityCheckResult.isValid ? ETokenIntegrityStatus.TRUSTED : ETokenIntegrityStatus.UNTRUSTED,
    integrityPackageName: integrityCheckResult.packageName ?? null,
    integrityAppRecognitionVerdict: integrityCheckResult.appRecognitionVerdict ?? null,
    integrityDeviceRecognitionVerdict: integrityCheckResult.deviceRecognitionVerdict
        ? JSON.stringify(integrityCheckResult.deviceRecognitionVerdict)
        : null,
    integrityAppLicensingVerdict: integrityCheckResult.appLicensingVerdict ?? null,
    integrityTimestamp: integrityCheckResult.requestTimestamp ?? null,
    integrityPublicKeyPem: null,
    integrityVerifyError: null,
    integrityCheckedAt: new Date().toISOString(),
    integrityRawResult: JSON.stringify(integrityCheckResult),
});

### 1.7 Extend `IntegrityCheckService.validateIosIntegrity` to pass details

**File:** `services/token/src/services/IntegrityCheckService.ts`  
**Lines:** 309–311

Current:
typescript
await tokenRepositoryClient.updateToken(tokenID, {
    integrityStatus: isValid ? ETokenIntegrityStatus.TRUSTED : ETokenIntegrityStatus.UNTRUSTED,
});

Change to:
typescript
const iosResult = verificationResult as Record<string, unknown>;
await tokenRepositoryClient.updateToken(tokenID, {
    integrityStatus: isValid ? ETokenIntegrityStatus.TRUSTED : ETokenIntegrityStatus.UNTRUSTED,
    integrityPackageName: null,
    integrityAppRecognitionVerdict: null,
    integrityDeviceRecognitionVerdict: null,
    integrityAppLicensingVerdict: null,
    integrityTimestamp: null,
    integrityPublicKeyPem: isValid && 'publicKeyPem' in iosResult
        ? String(iosResult.publicKeyPem)
        : null,
    integrityVerifyError: !isValid && 'verifyError' in iosResult
        ? String(iosResult.verifyError)
        : null,
    integrityCheckedAt: new Date().toISOString(),
    integrityRawResult: JSON.stringify(verificationResult),
});

### 1.8 Handle "missing token / missing keyID" cases with detail fields

In the same file `IntegrityCheckService.ts`, everywhere `updateToken` is called with only `integrityStatus: ETokenIntegrityStatus.UNTRUSTED` (lines 88–90, 156–158), also clear all integrity detail fields by setting them to `null` and set `integrityCheckedAt` to the current timestamp:

typescript
await tokenRepositoryClient.updateToken(tokenID, {
    integrityStatus: ETokenIntegrityStatus.UNTRUSTED,
    integrityPackageName: null,
    integrityAppRecognitionVerdict: null,
    integrityDeviceRecognitionVerdict: null,
    integrityAppLicensingVerdict: null,
    integrityTimestamp: null,
    integrityPublicKeyPem: null,
    integrityVerifyError: null,
    integrityCheckedAt: new Date().toISOString(),
    integrityRawResult: null,
});

---

## PHASE 2: gRPC Proto Definitions — Add New Fields

### 2.1 Extend `RpcUpdateTokenRequest`

**File:** `services/repository/src/protobuf/proto/services/repository/TokenRepository.proto`  
**Lines:** 242–255

Add new fields after field 12:
protobuf
message RpcUpdateTokenRequest {
  uint64 id = 1;
  optional string name = 2;
  optional string brand = 3;
  optional string model = 4;
  optional string systemName = 5;
  optional string systemVersion = 6;
  optional string appVersion = 7;
  optional string pushID = 8;
  optional string lastConnectedAt = 9;
  optional uint64 certificateID = 10;
  optional uint64 transactionID = 11;
  optional string integrityStatus = 12;
  optional string integrityPackageName = 13;
  optional string integrityAppRecognitionVerdict = 14;
  optional string integrityDeviceRecognitionVerdict = 15;
  optional string integrityAppLicensingVerdict = 16;
  optional string integrityTimestamp = 17;
  optional string integrityPublicKeyPem = 18;
  optional string integrityVerifyError = 19;
  optional string integrityCheckedAt = 20;
  optional string integrityRawResult = 21;
}

### 2.2 Extend `RpcCreateTokenRequest`

**File:** `services/repository/src/protobuf/proto/services/repository/TokenRepository.proto`  
**Lines:** 128–141

Add the same new fields (field numbers 13–21) to `RpcCreateTokenRequest`.

### 2.3 Extend `RpcTokenModel`

**File:** `services/repository/src/protobuf/proto/services/repository/models/token/RpcTokenModel.proto`

Add after field 13:
protobuf
message RpcTokenModel {
  uint64 id = 1;
  string udid = 2;
  string name = 3;
  string brand = 4;
  string model = 5;
  string systemName = 6;
  string systemVersion = 7;
  string appVersion = 8;
  string pushID = 9;
  string certificate = 10;
  string lastConnectedAt = 11;
  string createdAt = 12;
  optional string integrityStatus = 13;
  optional string integrityPackageName = 14;
  optional string integrityAppRecognitionVerdict = 15;
  optional string integrityDeviceRecognitionVerdict = 16;
  optional string integrityAppLicensingVerdict = 17;
  optional string integrityTimestamp = 18;
  optional string integrityPublicKeyPem = 19;
  optional string integrityVerifyError = 20;
  optional string integrityCheckedAt = 21;
  optional string integrityRawResult = 22;
}

### 2.4 Extend `RpcTokenDetailModel`

**File:** `services/repository/src/protobuf/proto/services/repository/models/token/RpcTokenDetailModel.proto`

Add after field 8:
protobuf
message RpcTokenDetailModel {
  uint64 id = 1;
  string deviceName = 2;
  string brand = 3;
  string model = 4;
  string systemName = 5;
  string systemVersion = 6;
  string createdAt = 7;
  optional string integrityStatus = 8;
  optional string integrityPackageName = 9;
  optional string integrityAppRecognitionVerdict = 10;
  optional string integrityDeviceRecognitionVerdict = 11;
  optional string integrityAppLicensingVerdict = 12;
  optional string integrityTimestamp = 13;
  optional string integrityPublicKeyPem = 14;
  optional string integrityVerifyError = 15;
  optional string integrityCheckedAt = 16;
  optional string integrityRawResult = 17;
}

### 2.5 Regenerate Proto Stubs

After modifying all `.proto` files, regenerate the JavaScript/TypeScript stubs. Run the proto generation command used in the project (check `package.json` scripts in the repository service — typically `npm run proto:generate` or similar).

---

## PHASE 3: Repository Service — Database & Logic

### 3.1 Create New Database Migration

Create a new migration file: `services/repository/src/migrations/YYYYMMDDHHMMSS_v_X.X.X_add_integrity_detail_columns.ts`

Follow the pattern of `services/repository/src/migrations/20241112160011_v_4.2.0_add_rule_integrity_check.ts`.

The migration must:

**a) Add columns to `Token` table:**
sql
ALTER TABLE `Token`
  ADD COLUMN `integrityPackageName` VARCHAR(255) NULL DEFAULT NULL,
  ADD COLUMN `integrityAppRecognitionVerdict` VARCHAR(50) NULL DEFAULT NULL,
  ADD COLUMN `integrityDeviceRecognitionVerdict` TEXT NULL DEFAULT NULL,
  ADD COLUMN `integrityAppLicensingVerdict` VARCHAR(50) NULL DEFAULT NULL,
  ADD COLUMN `integrityTimestamp` VARCHAR(50) NULL DEFAULT NULL,
  ADD COLUMN `integrityPublicKeyPem` TEXT NULL DEFAULT NULL,
  ADD COLUMN `integrityVerifyError` VARCHAR(100) NULL DEFAULT NULL,
  ADD COLUMN `integrityCheckedAt` DATETIME(3) NULL DEFAULT NULL,
  ADD COLUMN `integrityRawResult` TEXT NULL DEFAULT NULL;

**b) Add the same columns to `Audit_Token` table** (same column definitions).

**c) Recreate all three triggers** (`Token_InsertAuditTrigger`, `Token_UpdateAuditTrigger`, `Token_DeleteAuditTrigger`) to include the new columns.

The UPDATE trigger condition must include all new columns:
sql
CREATE TRIGGER `excalibur`.`Token_UpdateAuditTrigger` AFTER UPDATE ON `Token` FOR EACH ROW
BEGIN
    IF OLD.`userID` != NEW.`userID` OR
    OLD.`name` != NEW.`name` OR
    OLD.`systemVersion` != NEW.`systemVersion` OR
    OLD.`version` != NEW.`version` OR
    OLD.`pushID` != NEW.`pushID` OR
    OLD.`certificateID` != NEW.`certificateID` OR
    OLD.`integrityStatus` != NEW.`integrityStatus` OR
    OLD.`integrityPackageName` != NEW.`integrityPackageName` OR
    (OLD.`integrityPackageName` IS NULL) != (NEW.`integrityPackageName` IS NULL) OR
    OLD.`integrityAppRecognitionVerdict` != NEW.`integrityAppRecognitionVerdict` OR
    (OLD.`integrityAppRecognitionVerdict` IS NULL) != (NEW.`integrityAppRecognitionVerdict` IS NULL) OR
    OLD.`integrityDeviceRecognitionVerdict` != NEW.`integrityDeviceRecognitionVerdict` OR
    (OLD.`integrityDeviceRecognitionVerdict` IS NULL) != (NEW.`integrityDeviceRecognitionVerdict` IS NULL) OR
    OLD.`integrityAppLicensingVerdict` != NEW.`integrityAppLicensingVerdict` OR
    (OLD.`integrityAppLicensingVerdict` IS NULL) != (NEW.`integrityAppLicensingVerdict` IS NULL) OR
    OLD.`integrityTimestamp` != NEW.`integrityTimestamp` OR
    (OLD.`integrityTimestamp` IS NULL) != (NEW.`integrityTimestamp` IS NULL) OR
    OLD.`integrityPublicKeyPem` != NEW.`integrityPublicKeyPem` OR
    (OLD.`integrityPublicKeyPem` IS NULL) != (NEW.`integrityPublicKeyPem` IS NULL) OR
    OLD.`integrityVerifyError` != NEW.`integrityVerifyError` OR
    (OLD.`integrityVerifyError` IS NULL) != (NEW.`integrityVerifyError` IS NULL) OR
    OLD.`integrityCheckedAt` != NEW.`integrityCheckedAt` OR
    (OLD.`integrityCheckedAt` IS NULL) != (NEW.`integrityCheckedAt` IS NULL) OR
    OLD.`integrityRawResult` != NEW.`integrityRawResult` OR
    (OLD.`integrityRawResult` IS NULL) != (NEW.`integrityRawResult` IS NULL) OR
    OLD.`createdAt` != NEW.`createdAt` THEN

        INSERT INTO `Audit_Token`(
            `revType`, `id`, `userID`, `udid`, `name`, `brand`, `model`,
            `systemName`, `systemVersion`, `version`, `pushID`, `certificateID`,
            `lastConnectedAt`, `createdAt`, `modifiedAt`, `modifiedBy`,
            `integrityStatus`,
            `integrityPackageName`, `integrityAppRecognitionVerdict`,
            `integrityDeviceRecognitionVerdict`, `integrityAppLicensingVerdict`,
            `integrityTimestamp`, `integrityPublicKeyPem`, `integrityVerifyError`,
            `integrityCheckedAt`, `integrityRawResult`
        )
        VALUES (
            'update', NEW.`id`, NEW.`userID`, OLD.`udid`, NEW.`name`,
            OLD.`brand`, OLD.`model`, OLD.`systemName`, NEW.`systemVersion`,
            NEW.`version`, NEW.`pushID`, NEW.`certificateID`,
            NEW.`lastConnectedAt`, NEW.`createdAt`, CURRENT_TIMESTAMP(3),
            @Token_modifiedBy, NEW.`integrityStatus`,
            NEW.`integrityPackageName`, NEW.`integrityAppRecognitionVerdict`,
            NEW.`integrityDeviceRecognitionVerdict`, NEW.`integrityAppLicensingVerdict`,
            NEW.`integrityTimestamp`, NEW.`integrityPublicKeyPem`, NEW.`integrityVerifyError`,
            NEW.`integrityCheckedAt`, NEW.`integrityRawResult`
        );
    END IF;
    SET @last_revID = LAST_INSERT_ID();
END;

> **IMPORTANT:** MySQL `!=` comparison with NULL always returns NULL (falsy), so triggers that compare nullable columns must include explicit `(OLD.col IS NULL) != (NEW.col IS NULL)` checks to detect transitions between NULL and non-NULL values. The existing trigger already has this problem for `integrityStatus` but gets away with it because the `integrityStatus` column can only change from NULL→'trusted'/'untrusted' (initial insert) or between the two enum values, both of which are caught by `!=`. For the new nullable TEXT/VARCHAR columns, the `IS NULL` comparison is essential.

INSERT and DELETE triggers must also include all new columns in their column lists and value lists, following the same pattern as the existing trigger (INSERT uses `NEW.*`, DELETE uses `OLD.*`).

### 3.2 Extend `TokenEntity`

**File:** `services/repository/src/entity/token/TokenEntity.ts`

Add after `integrityStatus` (line 56):
typescript
integrityPackageName: Nullable<string>;
integrityAppRecognitionVerdict: Nullable<string>;
integrityDeviceRecognitionVerdict: Nullable<string>;
integrityAppLicensingVerdict: Nullable<string>;
integrityTimestamp: Nullable<string>;
integrityPublicKeyPem: Nullable<string>;
integrityVerifyError: Nullable<string>;
integrityCheckedAt: Nullable<Date>;
integrityRawResult: Nullable<string>;

### 3.3 Extend `TokenAuditEntity`

**File:** `services/repository/src/entity/token/TokenAudit.ts`

Add the same fields after `integrityStatus` (line 22):
typescript
integrityPackageName: Nullable<string>;
integrityAppRecognitionVerdict: Nullable<string>;
integrityDeviceRecognitionVerdict: Nullable<string>;
integrityAppLicensingVerdict: Nullable<string>;
integrityTimestamp: Nullable<string>;
integrityPublicKeyPem: Nullable<string>;
integrityVerifyError: Nullable<string>;
integrityCheckedAt: Nullable<Date>;
integrityRawResult: Nullable<string>;

### 3.4 Extend `UpdateTokenDto` in Repository Service

**File:** `services/repository/src/dto/token/UpdateTokenDto.ts`

Add after `integrityStatus` (line 13):
typescript
integrityPackageName?: string | null;
integrityAppRecognitionVerdict?: string | null;
integrityDeviceRecognitionVerdict?: string | null;
integrityAppLicensingVerdict?: string | null;
integrityTimestamp?: string | null;
integrityPublicKeyPem?: string | null;
integrityVerifyError?: string | null;
integrityCheckedAt?: Date | null;
integrityRawResult?: string | null;

### 3.5 Extend `TokenRepository` table config

**File:** `services/repository/src/repository/token/TokenRepository.ts`  
**Line:** 60 (after `integrityStatus: {}`)

Add:
typescript
integrityPackageName: {},
integrityAppRecognitionVerdict: {},
integrityDeviceRecognitionVerdict: {},
integrityAppLicensingVerdict: {},
integrityTimestamp: {},
integrityPublicKeyPem: {},
integrityVerifyError: {},
integrityCheckedAt: { type: EDbColumnType.DATE },
integrityRawResult: {},

Also extend the query `select` statements (lines 203, 279) to include the new columns in queries that use `token.*` selects.

### 3.6 Extend `TokenAuditRepository` table config

**File:** `services/repository/src/repository/token/TokenAuditRepository.ts`  
**Line:** 40 (after `integrityStatus: {}`)

Add:
typescript
integrityPackageName: {},
integrityAppRecognitionVerdict: {},
integrityDeviceRecognitionVerdict: {},
integrityAppLicensingVerdict: {},
integrityTimestamp: {},
integrityPublicKeyPem: {},
integrityVerifyError: {},
integrityCheckedAt: { type: EDbColumnType.DATE },
integrityRawResult: {},

Also extend the `getOneByClosestChangeTimestamp` select query (around line 167) to include the new columns.

### 3.7 Extend `TokenRepositoryService.updateToken`

**File:** `services/repository/src/service/token/TokenRepositoryService.ts`  
**Lines:** 844–854

After the existing `integrityStatus` extraction (line 844), add:
typescript
const integrityPackageName = request.hasIntegritypackagename() ? (request.getIntegritypackagename() ?? null) : null;
const integrityAppRecognitionVerdict = request.hasIntegrityapprecognitionverdict() ? (request.getIntegrityapprecognitionverdict() ?? null) : null;
const integrityDeviceRecognitionVerdict = request.hasIntegritydevicerecognitionverdict() ? (request.getIntegritydevicerecognitionverdict() ?? null) : null;
const integrityAppLicensingVerdict = request.hasIntegrityapplicensingverdict() ? (request.getIntegrityapplicensingverdict() ?? null) : null;
const integrityTimestamp = request.hasIntegritytimestamp() ? (request.getIntegritytimestamp() ?? null) : null;
const integrityPublicKeyPem = request.hasIntegritypublickeypem() ? (request.getIntegritypublickeypem() ?? null) : null;
const integrityVerifyError = request.hasIntegrityverifyerror() ? (request.getIntegrityverifyerror() ?? null) : null;
const integrityCheckedAt = request.hasIntegritycheckedat() ? (request.getIntegritycheckedat() ?? null) : null;
const integrityRawResult = request.hasIntegrityrawresult() ? (request.getIntegrityrawresult() ?? null) : null;

And in the mapping section (after line 854), add:
typescript
if (integrityPackageName !== undefined) {
    mappedToken.integrityPackageName = integrityPackageName;
}
if (integrityAppRecognitionVerdict !== undefined) {
    mappedToken.integrityAppRecognitionVerdict = integrityAppRecognitionVerdict;
}
if (integrityDeviceRecognitionVerdict !== undefined) {
    mappedToken.integrityDeviceRecognitionVerdict = integrityDeviceRecognitionVerdict;
}
if (integrityAppLicensingVerdict !== undefined) {
    mappedToken.integrityAppLicensingVerdict = integrityAppLicensingVerdict;
}
if (integrityTimestamp !== undefined) {
    mappedToken.integrityTimestamp = integrityTimestamp;
}
if (integrityPublicKeyPem !== undefined) {
    mappedToken.integrityPublicKeyPem = integrityPublicKeyPem;
}
if (integrityVerifyError !== undefined) {
    mappedToken.integrityVerifyError = integrityVerifyError;
}
if (integrityCheckedAt) {
    mappedToken.integrityCheckedAt = new Date(integrityCheckedAt);
}
if (integrityRawResult !== undefined) {
    mappedToken.integrityRawResult = integrityRawResult;
}

### 3.8 Extend `ActionRepositoryService.getActionToken` — MAP integrity details to response

**File:** `services/repository/src/service/action/ActionRepositoryService.ts`  
**Lines:** 745–761

Currently, `integrityStatus` is NOT mapped into the response (this is a known GAP). Add after line 760 (`rpcTokenModel.setCreatedat(...)`) or wherever appropriate:
typescript
if (auditToken.integrityStatus) {
    rpcTokenModel.setIntegritystatus(auditToken.integrityStatus);
}
if (auditToken.integrityPackageName) {
    rpcTokenModel.setIntegritypackagename(auditToken.integrityPackageName);
}
if (auditToken.integrityAppRecognitionVerdict) {
    rpcTokenModel.setIntegrityapprecognitionverdict(auditToken.integrityAppRecognitionVerdict);
}
if (auditToken.integrityDeviceRecognitionVerdict) {
    rpcTokenModel.setIntegritydevicerecognitionverdict(auditToken.integrityDeviceRecognitionVerdict);
}
if (auditToken.integrityAppLicensingVerdict) {
    rpcTokenModel.setIntegrityapplicensingverdict(auditToken.integrityAppLicensingVerdict);
}
if (auditToken.integrityTimestamp) {
    rpcTokenModel.setIntegritytimestamp(auditToken.integrityTimestamp);
}
if (auditToken.integrityPublicKeyPem) {
    rpcTokenModel.setIntegritypublickeypem(auditToken.integrityPublicKeyPem);
}
if (auditToken.integrityVerifyError) {
    rpcTokenModel.setIntegrityverifyerror(auditToken.integrityVerifyError);
}
if (auditToken.integrityCheckedAt) {
    rpcTokenModel.setIntegritycheckedat(auditToken.integrityCheckedAt.toISOString());
}
if (auditToken.integrityRawResult) {
    rpcTokenModel.setIntegrityrawresult(auditToken.integrityRawResult);
}

> **NOTE:** The `auditToken` variable type is `TokenAuditDto | TokenDto | null`. Make sure the type includes the new fields. Check if `TokenAuditDto` is mapped from `TokenAuditEntity` — if so, the entity changes from 3.3 should propagate automatically. Also ensure `TokenDto` includes them if it can be used as fallback.

---

## PHASE 4: Dashboard — Display Detailed Integrity Information

### 4.1 Extend Validation Results display for INTEGRITY_CHECK

**File:** `services/dashboard/src/pages/actions/Components/ActionDetail/ValidationResults.tsx`  
**Lines:** 217–227

Current:
typescript
case EResultType.INTEGRITY_CHECK: {
    const parsedIntegrityResult = parseValueToObject(value as string);

    return {
        name: t('page.action.detail.sections.validationResult.body.integrityCheck'),
        value:
            parsedIntegrityResult.isValid || parsedIntegrityResult.publicKeyPem ?
                t('page.action.detail.sections.validationResult.body.integrityCheckTrusted')
            :   t('page.action.detail.sections.validationResult.body.integrityCheckUntrusted'),
    };
}

Change to display detailed information:
typescript
case EResultType.INTEGRITY_CHECK: {
    const parsedIntegrityResult = parseValueToObject(value as string);
    const isTrusted = parsedIntegrityResult.isValid || parsedIntegrityResult.publicKeyPem;
    const statusText = isTrusted
        ? t('page.action.detail.sections.validationResult.body.integrityCheckTrusted')
        : t('page.action.detail.sections.validationResult.body.integrityCheckUntrusted');

    const details: string[] = [statusText];

    // Android detailed attributes
    if (parsedIntegrityResult.deviceRecognitionVerdict) {
        const verdicts = Array.isArray(parsedIntegrityResult.deviceRecognitionVerdict)
            ? parsedIntegrityResult.deviceRecognitionVerdict
            : [];
        details.push(
            `${t('page.action.detail.sections.validationResult.body.integrityDeviceVerdict')}: ${
                verdicts.length > 0
                    ? verdicts.map((v: string) => t(`page.action.detail.sections.validationResult.body.integrityDeviceVerdictValue.${v}`, { defaultValue: v })).join(', ')
                    : t('page.action.detail.sections.validationResult.body.integrityDeviceVerdictNone')
            }`
        );
    }
    if (parsedIntegrityResult.appRecognitionVerdict) {
        details.push(
            `${t('page.action.detail.sections.validationResult.body.integrityAppVerdict')}: ${
                t(`page.action.detail.sections.validationResult.body.integrityAppVerdictValue.${parsedIntegrityResult.appRecognitionVerdict}`, { defaultValue: parsedIntegrityResult.appRecognitionVerdict })
            }`
        );
    }
    if (parsedIntegrityResult.appLicensingVerdict) {
        details.push(
            `${t('page.action.detail.sections.validationResult.body.integrityLicensingVerdict')}: ${
                t(`page.action.detail.sections.validationResult.body.integrityLicensingVerdictValue.${parsedIntegrityResult.appLicensingVerdict}`, { defaultValue: parsedIntegrityResult.appLicensingVerdict })
            }`
        );
    }
    if (parsedIntegrityResult.packageName) {
        details.push(
            `${t('page.action.detail.sections.validationResult.body.integrityPackageName')}: ${parsedIntegrityResult.packageName}`
        );
    }

    // iOS detailed attributes
    if (parsedIntegrityResult.publicKeyPem) {
        details.push(t('page.action.detail.sections.validationResult.body.integrityIosAttestationVerified'));
    }
    if (parsedIntegrityResult.verifyError) {
        details.push(
            `${t('page.action.detail.sections.validationResult.body.integrityIosError')}: ${
                t(`page.action.detail.sections.validationResult.body.integrityIosErrorValue.${parsedIntegrityResult.verifyError}`, { defaultValue: parsedIntegrityResult.verifyError })
            }`
        );
    }

    return {
        name: t('page.action.detail.sections.validationResult.body.integrityCheck'),
        value: details,
    };
}

### 4.2 Add Translation Keys

Add the following keys to the relevant i18n JSON translation files (e.g. `en.json`, `sk.json`):

**English (`en.json`):**
json
{
  "page.action.detail.sections.validationResult.body.integrityDeviceVerdict": "Device integrity",
  "page.action.detail.sections.validationResult.body.integrityDeviceVerdictValue.MEETS_DEVICE_INTEGRITY": "Meets device integrity",
  "page.action.detail.sections.validationResult.body.integrityDeviceVerdictValue.MEETS_BASIC_INTEGRITY": "Meets basic integrity",
  "page.action.detail.sections.validationResult.body.integrityDeviceVerdictValue.MEETS_STRONG_INTEGRITY": "Meets strong integrity",
  "page.action.detail.sections.validationResult.body.integrityDeviceVerdictValue.MEETS_VIRTUAL_INTEGRITY": "Virtual device (emulator)",
  "page.action.detail.sections.validationResult.body.integrityDeviceVerdictNone": "Device did not pass integrity check",
  "page.action.detail.sections.validationResult.body.integrityAppVerdict": "App recognition",
  "page.action.detail.sections.validationResult.body.integrityAppVerdictValue.PLAY_RECOGNIZED": "Recognized via Play Store",
  "page.action.detail.sections.validationResult.body.integrityAppVerdictValue.UNRECOGNIZED_VERSION": "Unrecognized version",
  "page.action.detail.sections.validationResult.body.integrityAppVerdictValue.UNEVALUATED": "Not evaluated",
  "page.action.detail.sections.validationResult.body.integrityLicensingVerdict": "App licensing",
  "page.action.detail.sections.validationResult.body.integrityLicensingVerdictValue.LICENSED": "Licensed",
  "page.action.detail.sections.validationResult.body.integrityLicensingVerdictValue.UNLICENSED": "Unlicensed",
  "page.action.detail.sections.validationResult.body.integrityLicensingVerdictValue.UNEVALUATED": "Not evaluated",
  "page.action.detail.sections.validationResult.body.integrityPackageName": "Package name",
  "page.action.detail.sections.validationResult.body.integrityIosAttestationVerified": "Device attestation verified (Apple App Attest)",
  "page.action.detail.sections.validationResult.body.integrityIosError": "Attestation failure reason",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_parsing_attestation": "Failed to parse attestation data",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_credId_len_invalid": "Invalid credential identifier length",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_credId_mismatch": "Credential identifier mismatch",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_aaguid_mismatch": "AAGUID mismatch",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_signCount_nonZero": "Sign count should be zero",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_rpId_mismatch": "Relying party ID mismatch",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_keyId_mismatch": "Key ID mismatch",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_nonce_missing": "Nonce not found",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_nonce_mismatch": "Nonce mismatch",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_credCert_verify_failure": "Credential certificate verification failed",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_intermediateCert_verify_failure": "Intermediate certificate verification failed"
}

**Slovak (`sk.json`):**
json
{
  "page.action.detail.sections.validationResult.body.integrityDeviceVerdict": "Integrita zariadenia",
  "page.action.detail.sections.validationResult.body.integrityDeviceVerdictValue.MEETS_DEVICE_INTEGRITY": "Spĺňa integritu zariadenia",
  "page.action.detail.sections.validationResult.body.integrityDeviceVerdictValue.MEETS_BASIC_INTEGRITY": "Spĺňa základnú integritu",
  "page.action.detail.sections.validationResult.body.integrityDeviceVerdictValue.MEETS_STRONG_INTEGRITY": "Spĺňa prísnú integritu",
  "page.action.detail.sections.validationResult.body.integrityDeviceVerdictValue.MEETS_VIRTUAL_INTEGRITY": "Virtuálne zariadenie (emulátor)",
  "page.action.detail.sections.validationResult.body.integrityDeviceVerdictNone": "Zariadenie neprešlo kontrolou integrity",
  "page.action.detail.sections.validationResult.body.integrityAppVerdict": "Rozpoznanie aplikácie",
  "page.action.detail.sections.validationResult.body.integrityAppVerdictValue.PLAY_RECOGNIZED": "Rozpoznaná cez Play Store",
  "page.action.detail.sections.validationResult.body.integrityAppVerdictValue.UNRECOGNIZED_VERSION": "Nerozpoznaná verzia",
  "page.action.detail.sections.validationResult.body.integrityAppVerdictValue.UNEVALUATED": "Nevyhodnotené",
  "page.action.detail.sections.validationResult.body.integrityLicensingVerdict": "Licencia aplikácie",
  "page.action.detail.sections.validationResult.body.integrityLicensingVerdictValue.LICENSED": "Licencovaná",
  "page.action.detail.sections.validationResult.body.integrityLicensingVerdictValue.UNLICENSED": "Nelicencovaná",
  "page.action.detail.sections.validationResult.body.integrityLicensingVerdictValue.UNEVALUATED": "Nevyhodnotené",
  "page.action.detail.sections.validationResult.body.integrityPackageName": "Názov balíka",
  "page.action.detail.sections.validationResult.body.integrityIosAttestationVerified": "Atestácia zariadenia overená (Apple App Attest)",
  "page.action.detail.sections.validationResult.body.integrityIosError": "Dôvod zlyhania atestácie",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_parsing_attestation": "Nepodarilo sa spracovať atestačné dáta",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_credId_len_invalid": "Neplatná dĺžka identifikátora poverenia",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_credId_mismatch": "Nesúlad identifikátora poverenia",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_aaguid_mismatch": "Nesúlad AAGUID",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_signCount_nonZero": "Počet podpisov by mal byť nula",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_rpId_mismatch": "Nesúlad ID spoliehajúcej sa strany",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_keyId_mismatch": "Nesúlad ID kľúča",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_nonce_missing": "Nonce nebol nájdený",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_nonce_mismatch": "Nesúlad nonce",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_credCert_verify_failure": "Overenie certifikátu poverenia zlyhalo",
  "page.action.detail.sections.validationResult.body.integrityIosErrorValue.fail_intermediateCert_verify_failure": "Overenie sprostredkujúceho certifikátu zlyhalo"
}

> **NOTE:** Locate the actual translation file paths — they might be in `services/dashboard/public/locales/en/translation.json` and `services/dashboard/public/locales/sk/translation.json`, or similar. Search for existing keys like `integrityCheckTrusted` to find the exact files.

### 4.3 Extend Token Audit Logs Display (if needed)

**File:** `services/dashboard/src/pages/tokens/AuditLogsSection.tsx`

The audit logs likely use `AuditEvent` records which have change details (old/new values via `findChanges`). Since `findChanges` in `TokenRepositoryService.updateToken` already detects changes in `mappedTokenData` (which will now include new integrity fields), the audit events will automatically contain entries like:
json
{
  "integrityDeviceRecognitionVerdict": {
    "oldValue": "[\"MEETS_DEVICE_INTEGRITY\"]",
    "newValue": "[]"
  }
}

However, review `AuditLogsSection.tsx` to ensure these new fields are displayed in a human-readable format with proper translation labels. The display may need to map field names to translation keys.

### 4.4 Optional: Extend Token List tooltip

**File:** `services/dashboard/src/pages/tokens/TokenList.tsx`  
**Lines:** 338–347

Currently shows simple trusted/untrusted icons with tooltip text. Optionally extend the tooltip to include a summary of the latest integrity check details (e.g. device verdict for Android, attestation status for iOS). This requires the token list API response to include the new fields.

---

## PHASE 5: Verification Checklist

After implementing all changes:

1. **Proto regeneration:** Regenerate all protobuf stubs and verify no compilation errors in both token and repository services.

2. **Migration:** Run the new database migration on a dev database and verify:
   - All 9 new columns exist in both `Token` and `Audit_Token` tables
   - All 3 triggers (INSERT, UPDATE, DELETE) are correctly recreated
   - The UPDATE trigger fires when any integrity detail column changes

3. **Token Service tests:** Verify that:
   - `GoogleApiClient.validateIntegrity` returns `requestTimestamp` field
   - `IntegrityCheckService` passes all new fields to `updateToken`
   - The typo fix (`deviceRecogitionVerdict` → `deviceRecognitionVerdict`) doesn't break anything

4. **Repository Service tests:** Verify that:
   - `updateToken` correctly maps all new fields from the gRPC request
   - `findChanges` detects changes in the new fields
   - `getActionToken` correctly maps integrity details into the response

5. **Dashboard tests:** Verify that:
   - `ValidationResults` renders detailed Android integrity info (device verdict, app recognition, licensing, package name)
   - `ValidationResults` renders detailed iOS integrity info (attestation verified / error reason)
   - Translation keys exist in both `en` and `sk` locale files
   - Edge case: when Google API communication fails (only `isValid: false`, no details), the UI shows a graceful "details not available" message

6. **End-to-end test:** Perform integrity check from a device and verify:
   - Detailed attributes are stored in `Token` table
   - Audit record in `Audit_Token` contains the same details
   - `AuditEvent` records show old→new changes for integrity fields
   - Dashboard action detail shows detailed integrity information
   - Dashboard token audit logs show integrity detail changes

---

## File Reference Summary

| Layer | File | Changes |
|-------|------|---------|
| **Token Service** | `services/token/src/clients/GoogleApiClient.ts` | Extend interface, fix typo, add `requestTimestamp` |
| **Token Service** | `services/token/src/services/IntegrityCheckService.ts` | Pass detail fields to `updateToken` in all branches |
| **Token Service** | `services/token/src/dtos/token/UpdateTokenDto.ts` | Add 9 new optional fields |
| **Token Service** | `services/token/src/clients/repository/TokenRepositoryClient.ts` | Add setters for new gRPC fields |
| **Proto** | `services/repository/src/protobuf/proto/services/repository/TokenRepository.proto` | Extend `RpcCreateTokenRequest` + `RpcUpdateTokenRequest` |
| **Proto** | `services/repository/src/protobuf/proto/services/repository/models/token/RpcTokenModel.proto` | Add 9 new optional fields |
| **Proto** | `services/repository/src/protobuf/proto/services/repository/models/token/RpcTokenDetailModel.proto` | Add 9 new optional fields |
| **Repository** | `services/repository/src/migrations/new_migration.ts` | New migration: columns + triggers |
| **Repository** | `services/repository/src/entity/token/TokenEntity.ts` | Add 9 new fields |
| **Repository** | `services/repository/src/entity/token/TokenAudit.ts` | Add 9 new fields |
| **Repository** | `services/repository/src/dto/token/UpdateTokenDto.ts` | Add 9 new optional fields |
| **Repository** | `services/repository/src/repository/token/TokenRepository.ts` | Extend table config + select queries |
| **Repository** | `services/repository/src/repository/token/TokenAuditRepository.ts` | Extend table config + select queries |
| **Repository** | `services/repository/src/service/token/TokenRepositoryService.ts` | Map new fields in `updateToken` |
| **Repository** | `services/repository/src/service/action/ActionRepositoryService.ts` | Map integrity details in `getActionToken` (fix existing GAP) |
| **Dashboard** | `services/dashboard/src/pages/actions/Components/ActionDetail/ValidationResults.tsx` | Extend INTEGRITY_CHECK display |
| **Dashboard** | Translation files (`en.json`, `sk.json`) | Add ~30 new translation keys |
| **Dashboard** | `services/dashboard/src/pages/tokens/AuditLogsSection.tsx` | Review/extend audit log detail display |
| **Dashboard** | `services/dashboard/src/pages/tokens/TokenList.tsx` | Optional: extend tooltip with details |