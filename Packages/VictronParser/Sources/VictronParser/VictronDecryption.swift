import CommonCrypto
import Foundation

enum VictronDecryptionError: Error, Equatable {
    case invalidKeyLength(Int)
    case cryptorCreateFailed(CCCryptorStatus)
    case cryptorUpdateFailed(CCCryptorStatus)
    case cryptorFinalFailed(CCCryptorStatus)
}

enum VictronDecryption {
    static func decrypt(
        encryptedPayload: Data,
        key: Data,
        nonce: UInt16
    ) throws -> Data {
        guard key.count == kCCKeySizeAES128 else {
            throw VictronDecryptionError.invalidKeyLength(key.count)
        }

        guard !encryptedPayload.isEmpty else {
            return Data()
        }

        var counterBlock = [UInt8](repeating: 0, count: kCCBlockSizeAES128)
        counterBlock[0] = UInt8(truncatingIfNeeded: nonce)
        counterBlock[1] = UInt8(truncatingIfNeeded: nonce >> 8)

        var cryptor: CCCryptorRef?

        // CryptoKit documents AES.GCM and AES.KeyWrap, but not AES-CTR. Victron
        // Instant Readout uses AES-128-CTR, so this layer uses CommonCrypto's
        // kCCModeCTR directly.
        //
        // OPEN QUESTION: CommonCrypto currently documents only big-endian CTR
        // increments. Victron records are currently <=16 bytes, so only the
        // initial counter block is used and increment endianness is irrelevant.
        let createStatus = key.withUnsafeBytes { keyBytes in
            counterBlock.withUnsafeBytes { counterBytes in
                CCCryptorCreateWithMode(
                    CCOperation(kCCDecrypt),
                    CCMode(kCCModeCTR),
                    CCAlgorithm(kCCAlgorithmAES),
                    CCPadding(ccNoPadding),
                    counterBytes.baseAddress,
                    keyBytes.baseAddress,
                    key.count,
                    nil,
                    0,
                    0,
                    CCModeOptions(kCCModeOptionCTR_BE),
                    &cryptor
                )
            }
        }

        guard createStatus == kCCSuccess, let cryptor else {
            throw VictronDecryptionError.cryptorCreateFailed(createStatus)
        }

        defer {
            CCCryptorRelease(cryptor)
        }

        var output = Data(count: encryptedPayload.count + kCCBlockSizeAES128)
        let outputCapacity = output.count
        var updateBytesWritten = 0

        let updateStatus = output.withUnsafeMutableBytes { outputBytes in
            encryptedPayload.withUnsafeBytes { inputBytes in
                CCCryptorUpdate(
                    cryptor,
                    inputBytes.baseAddress,
                    encryptedPayload.count,
                    outputBytes.baseAddress,
                    outputCapacity,
                    &updateBytesWritten
                )
            }
        }

        guard updateStatus == kCCSuccess else {
            throw VictronDecryptionError.cryptorUpdateFailed(updateStatus)
        }

        var finalBytesWritten = 0
        let finalStatus = output.withUnsafeMutableBytes { outputBytes in
            CCCryptorFinal(
                cryptor,
                outputBytes.baseAddress?.advanced(by: updateBytesWritten),
                outputCapacity - updateBytesWritten,
                &finalBytesWritten
            )
        }

        guard finalStatus == kCCSuccess else {
            throw VictronDecryptionError.cryptorFinalFailed(finalStatus)
        }

        output.removeSubrange((updateBytesWritten + finalBytesWritten)..<output.count)
        return output
    }
}
