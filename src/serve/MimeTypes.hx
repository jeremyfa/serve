package serve;

class MimeTypes {

    static final mimeTypes:Map<String, String> = [
        // Text
        "html" => "text/html",
        "htm" => "text/html",
        "css" => "text/css",
        "txt" => "text/plain",
        "csv" => "text/csv",
        "xml" => "text/xml",

        // JavaScript
        "js" => "application/javascript",
        "mjs" => "application/javascript",
        "json" => "application/json",

        // Images
        "jpg" => "image/jpeg",
        "jpeg" => "image/jpeg",
        "png" => "image/png",
        "gif" => "image/gif",
        "svg" => "image/svg+xml",
        "ico" => "image/x-icon",
        "webp" => "image/webp",
        "avif" => "image/avif",

        // Fonts
        "woff" => "font/woff",
        "woff2" => "font/woff2",
        "ttf" => "font/ttf",
        "otf" => "font/otf",
        "eot" => "application/vnd.ms-fontobject",

        // Audio
        "mp3" => "audio/mpeg",
        "wav" => "audio/wav",
        "ogg" => "audio/ogg",
        "m4a" => "audio/mp4",
        "aac" => "audio/aac",
        "webm" => "audio/webm",

        // Video
        "mp4" => "video/mp4",
        "avi" => "video/x-msvideo",
        "mpeg" => "video/mpeg",
        "ogv" => "video/ogg",
        "mov" => "video/quicktime",
        "wmv" => "video/x-ms-wmv",
        "flv" => "video/x-flv",
        "mkv" => "video/x-matroska",

        // Documents
        "pdf" => "application/pdf",
        "doc" => "application/msword",
        "docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "xls" => "application/vnd.ms-excel",
        "xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "ppt" => "application/vnd.ms-powerpoint",
        "pptx" => "application/vnd.openxmlformats-officedocument.presentationml.presentation",

        // Archives
        "zip" => "application/zip",
        "rar" => "application/vnd.rar",
        "tar" => "application/x-tar",
        "gz" => "application/gzip",
        "7z" => "application/x-7z-compressed",

        // Web Assembly
        "wasm" => "application/wasm",

        // Other
        "bin" => "application/octet-stream",
        "exe" => "application/octet-stream",
        "dll" => "application/octet-stream",
        "deb" => "application/octet-stream",
        "dmg" => "application/octet-stream",
        "iso" => "application/octet-stream",
        "msi" => "application/octet-stream"
    ];

    public static function getContentType(extension:String):String {
        var ext = extension.toLowerCase();
        return mimeTypes.get(ext) ?? "application/octet-stream";
    }

}