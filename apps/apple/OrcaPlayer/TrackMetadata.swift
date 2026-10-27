import Foundation

/// One title/artist/cover precedence for library rows and system media publication.
struct TrackMetadata: Equatable, Sendable {
    let title: String
    let artist: String
    let artwork: Data?
    static func resolve(_ track: AudioTrack, details: SongDetails?,
                        artistByID: (String) -> MusicArtist?, artistByName: (String) -> MusicArtist?) -> TrackMetadata {
        let name = details?.artistID.flatMap { artistByID($0)?.name }
            ?? (track.artist == "本機音檔" ? "未知歌手" : track.artist)
        return TrackMetadata(title: details?.title ?? track.title, artist: name,
                             artwork: details?.cover ?? artistByName(name)?.avatar)
    }
}
extension MusicCollection {
    /// Selected-track updates use this small projection, not a full-library rebuild.
    func metadata(for track: AudioTrack) -> TrackMetadata {
        TrackMetadata.resolve(track, details: songs[track.id],
            artistByID: { id in artists.first { $0.id == id } },
            artistByName: { name in artists.first { $0.name == name } })
    }
}
