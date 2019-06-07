//
// Copyright (c) 2019 Commercetools. All rights reserved.
//

import Commercetools

struct ImageSearch: MLEndpoint {

    typealias ResponseType = ImageSearchProduct

    static let path = "image-search"

    private static let targetSize = CGSize(width: 224, height: 224)
    private static let imageRenderer = UIGraphicsImageRenderer(size: targetSize)

    /**
        Initiates image search.

        - parameter image:                    A image used for products search.
        - parameter limit:                    An optional parameter to limit the number of returned results.
        - parameter offset:                   An optional parameter to set the offset of the first returned result.
        - parameter result:                   The code to be executed after processing the response.
    */
    static func perform(for image: UIImage, limit: UInt? = nil, offset: UInt? = nil, result: @escaping (Result<QueryResponse<ResponseType>>) -> Void) {
        requestWithTokenAndPath(result, { token, path in
            let resizedImage = imageRenderer.image { context in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }

            guard let data = resizedImage.jpegData(compressionQuality: 0.5) else {
                result(.failure(nil, [CTError.generalError(reason: nil)]))
                return
            }

            var request = self.request(url: path, method: .post, queryItems: [], json: nil, headers: self.headers(token))
            let boundary = NSUUID().uuidString

            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            var body = Data()
            body.appendString("--\(boundary)\r\nContent-Disposition: form-data; name=\"image\"; filename=\"image.jpeg\"\r\nContent-Type: image/jpeg\r\n\r\n")
            body.append(data)
            body.appendString("\r\n--\(boundary)--\r\n")
            request.httpBody = body
            request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")

            perform(request: request) { (response: Result<QueryResponse<ResponseType>>) in
                result(response)
            }
        })
    }
}

struct ImageSearchProduct: Codable {
    public let staged: Bool?
    public let productVariants: [ProductVariant]

    public struct ProductVariant: Codable {
        public let staged: Bool
        public let product: ResourceIdentifier?
        public let imageUrl: String?
        public let variantId: Int?
    }
}

extension Data {
    mutating func appendString(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        append(data)
    }
}
