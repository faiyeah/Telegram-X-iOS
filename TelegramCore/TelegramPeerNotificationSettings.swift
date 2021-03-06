import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public enum PeerMuteState: Equatable {
    case unmuted
    case muted(until: Int32)
    
    fileprivate static func decodeInline(_ decoder: PostboxDecoder) -> PeerMuteState {
        switch decoder.decodeInt32ForKey("m.v", orElse: 0) {
            case 0:
                return .unmuted
            case 1:
                return .muted(until: decoder.decodeInt32ForKey("m.u", orElse: 0))
            default:
                return .unmuted
        }
    }
    
    fileprivate func encodeInline(_ encoder: PostboxEncoder) {
        switch self {
            case .unmuted:
                encoder.encodeInt32(0, forKey: "m.v")
            case let .muted(until):
                encoder.encodeInt32(1, forKey: "m.v")
                encoder.encodeInt32(until, forKey: "m.u")
        }
    }
    
    public static func ==(lhs: PeerMuteState, rhs: PeerMuteState) -> Bool {
        switch lhs {
            case .unmuted:
                switch rhs {
                    case .unmuted:
                        return true
                    default:
                        return false
                }
            case let .muted(lhsUntil):
                switch rhs {
                    case .muted(lhsUntil):
                        return true
                    default:
                        return false
                }
        }
    }
}

private enum PeerMessageSoundValue: Int32 {
    case none
    case bundledModern
    case bundledClassic
    case `default`
}

public enum PeerMessageSound: Equatable {
    case none
    case `default`
    case bundledModern(id: Int32)
    case bundledClassic(id: Int32)
    
    static func decodeInline(_ decoder: PostboxDecoder) -> PeerMessageSound {
        switch decoder.decodeInt32ForKey("s.v", orElse: 0) {
            case PeerMessageSoundValue.none.rawValue:
                return .none
            case PeerMessageSoundValue.bundledModern.rawValue:
                return .bundledModern(id: decoder.decodeInt32ForKey("s.i", orElse: 0))
            case PeerMessageSoundValue.bundledClassic.rawValue:
                return .bundledClassic(id: decoder.decodeInt32ForKey("s.i", orElse: 0))
            case PeerMessageSoundValue.default.rawValue:
                return .default
            default:
                assertionFailure()
                return .bundledModern(id: 0)
        }
    }
    
    func encodeInline(_ encoder: PostboxEncoder) {
        switch self {
            case .none:
                encoder.encodeInt32(PeerMessageSoundValue.none.rawValue, forKey: "s.v")
            case let .bundledModern(id):
                encoder.encodeInt32(PeerMessageSoundValue.bundledModern.rawValue, forKey: "s.v")
                encoder.encodeInt32(id, forKey: "s.i")
            case let .bundledClassic(id):
                encoder.encodeInt32(PeerMessageSoundValue.bundledClassic.rawValue, forKey: "s.v")
                encoder.encodeInt32(id, forKey: "s.i")
            case .default:
                encoder.encodeInt32(PeerMessageSoundValue.default.rawValue, forKey: "s.v")
        }
    }
    
    public static func ==(lhs: PeerMessageSound, rhs: PeerMessageSound) -> Bool {
        switch lhs {
            case .none:
                if case .none = rhs {
                    return true
                } else {
                    return false
                }
            case let .bundledModern(id):
                if case .bundledModern(id) = rhs {
                    return true
                } else {
                    return false
                }
            case let .bundledClassic(id):
                if case .bundledClassic(id) = rhs {
                    return true
                } else {
                    return false
                }
            case .default:
                if case .default = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public final class TelegramPeerNotificationSettings: PeerNotificationSettings, Equatable {
    public let muteState: PeerMuteState
    public let messageSound: PeerMessageSound
    
    public static var defaultSettings: TelegramPeerNotificationSettings {
        return TelegramPeerNotificationSettings(muteState: .unmuted, messageSound: .default)
    }
    
    public var isRemovedFromTotalUnreadCount: Bool {
        switch self.muteState {
            case .unmuted:
                return false
            case .muted:
                return true
        }
    }
    
    public init(muteState: PeerMuteState, messageSound: PeerMessageSound) {
        self.muteState = muteState
        self.messageSound = messageSound
    }
    
    public init(decoder: PostboxDecoder) {
        self.muteState = PeerMuteState.decodeInline(decoder)
        self.messageSound = PeerMessageSound.decodeInline(decoder)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        self.muteState.encodeInline(encoder)
        self.messageSound.encodeInline(encoder)
    }
    
    public func isEqual(to: PeerNotificationSettings) -> Bool {
        if let to = to as? TelegramPeerNotificationSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public func withUpdatedMuteState(_ muteState: PeerMuteState) -> TelegramPeerNotificationSettings {
        return TelegramPeerNotificationSettings(muteState: muteState, messageSound: self.messageSound)
    }
    
    public func withUpdatedMessageSound(_ messageSound: PeerMessageSound) -> TelegramPeerNotificationSettings {
        return TelegramPeerNotificationSettings(muteState: self.muteState, messageSound: messageSound)
    }
    
    public static func ==(lhs: TelegramPeerNotificationSettings, rhs: TelegramPeerNotificationSettings) -> Bool {
        return lhs.muteState == rhs.muteState && lhs.messageSound == rhs.messageSound
    }
}

extension TelegramPeerNotificationSettings {
    convenience init(apiSettings: Api.PeerNotifySettings) {
        switch apiSettings {
            case .peerNotifySettingsEmpty:
                self.init(muteState: .unmuted, messageSound: .bundledModern(id: 0))
            case let .peerNotifySettings(_, muteUntil, sound):
                self.init(muteState: muteUntil == 0 ? .unmuted : .muted(until: muteUntil), messageSound: PeerMessageSound(apiSound: sound))
        }
    }
}

extension PeerMessageSound {
    init(apiSound: String) {
        var rawApiSound = apiSound
        if let index = rawApiSound.index(of: ".") {
            rawApiSound = String(rawApiSound[..<index])
        }
        
        let parsedSound: PeerMessageSound
        if rawApiSound == "default" {
            parsedSound = .default
        } else if rawApiSound == "" || rawApiSound == "0" {
            parsedSound = .none
        } else {
            let soundId: Int32
            if let id = Int32(rawApiSound) {
                soundId = id
            } else {
                soundId = 100
            }
            if soundId >= 100 && soundId <= 111 {
                parsedSound = .bundledModern(id: soundId - 100)
            } else if soundId >= 2 && soundId <= 9 {
                parsedSound = .bundledClassic(id: soundId - 2)
            } else {
                parsedSound = .bundledModern(id: 0)
            }
        }
        self = parsedSound
    }
    
    var apiSound: String {
        switch self {
            case .none:
                return ""
            case .default:
                return "default"
            case let .bundledModern(id):
                if id == 0 {
                    return "default"
                } else {
                    return "\(id + 100)"
                }
            case let .bundledClassic(id):
                return "\(id + 2)"
        }
    }
}
