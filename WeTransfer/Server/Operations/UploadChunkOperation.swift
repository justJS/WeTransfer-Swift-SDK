//
//  UploadChunkOperation.swift
//  WeTransfer
//
//  Created by Pim Coumans on 01/06/2018.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import Foundation

class UploadChunkOperation: ChainedAsynchronousResultOperation<Chunk, Chunk> {
	
	enum Error: Swift.Error {
		case noChunkDataAvailable
		case fileNotYetAdded
		case uploadFailed
	}
	
	let session: URLSession
	
	required init(session: URLSession) {
		self.session = session
		super.init()
	}
	
	override func execute(_ chunk: Chunk) {
		
		guard let data = try? chunk.data() else {
			self.finish(with: .failure(Error.noChunkDataAvailable))
			return
		}

		let uploadEndpoint = APIEndpoint.upload(url: chunk.uploadURL)
		var urlRequest = URLRequest(url: chunk.uploadURL)
		urlRequest.httpMethod = uploadEndpoint.method.rawValue
		let task = self.session.uploadTask(with: urlRequest, from: data) { (_, urlResponse, error) in
			if let error = error {
				self.finish(with: .failure(error))
				return
			}
			if let response = urlResponse as? HTTPURLResponse, !(200...299).contains(response.statusCode) {
				self.finish(with: .failure(Error.uploadFailed))
				return
			}
			self.finish(with: .success(chunk))
		}
		task.resume()
	}
}