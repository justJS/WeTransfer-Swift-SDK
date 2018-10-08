//
//  CompleteUploadOperation.swift
//  WeTransfer
//
//  Created by Pim Coumans on 01/06/2018.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import Foundation

/// Completes the upload of each file in a transfer. Typically used in `UploadFileOperation` after all the file's chunks have been uploaded
final class CompleteUploadOperation: AsynchronousResultOperation<File> {
	
	enum Error: Swift.Error, LocalizedError {
		/// File has not been added to the transfer yet
		case fileNotYetAdded
		
		var localizedDescription: String {
			switch self {
			case .fileNotYetAdded:
				return "File has not been added to the transfer yet"
			}
		}
	}
	
	/// File to complete the uploading of
	private let file: File
	
	/// Transfer or Board containing file
	private let container: Transferrable
	
	/// Initializes the operation with a file to complete the upload for
	///
	/// - Parameters:
	///   - container: Transferrable object containing the file
	///   - file: File struct for which to complete the upload for
	required init(container: Transferrable, file: File) {
		self.container = container
		self.file = file
		super.init()
	}
	
	override func execute() {
		
		guard let containerIdentifier = container.identifier,
			let fileIdentifier = file.identifier,
			let numberOfChunks = file.numberOfChunks else {
			finish(with: .failure(Error.fileNotYetAdded))
			return
		}
		
		let resultDependencies = dependencies.compactMap({ $0 as? AsynchronousResultOperation<Chunk> })
		let errors = resultDependencies.compactMap({ $0.result?.error })
		
		if let error = errors.last {
			finish(with: .failure(error))
			return
		}
		
		guard container is Transfer || container is Board else {
			fatalError("Container type '\(type(of: container))' is not supported")
		}
		
		if container is Transfer {
			let request: APIEndpoint = .completeTransferFileUpload(transferIdentifier: containerIdentifier, fileIdentifier: fileIdentifier)
			let parameters = CompleteTransferFileUploadParameters(partNumbers: numberOfChunks)
			WeTransfer.request(request, parameters: parameters) { [weak self] result in
				guard let self = self else {
					return
				}
				switch result {
				case .failure(let error):
					self.finish(with: .failure(error))
				case .success:
					self.finish(with: .success(self.file))
				}
			}
		} else if container is Board {
			WeTransfer.request(.completeBoardFileUpload(boardIdentifier: containerIdentifier, fileIdentifier: fileIdentifier)) { [weak self] result in
				guard let self = self else {
					return
				}
				switch result {
				case .failure(let error):
					self.finish(with: .failure(error))
				case .success(let response):
					guard response.success else {
						self.finish(with: .failure(WeTransfer.RequestError.serverError(errorMessage: response.message, httpCode: nil)))
						return
					}
					self.finish(with: .success(self.file))
				}
			}
		}
	}
	
}
