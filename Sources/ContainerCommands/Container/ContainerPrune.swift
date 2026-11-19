//===----------------------------------------------------------------------===//
// Copyright © 2026 Apple Inc. and the container project authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//===----------------------------------------------------------------------===//

import ArgumentParser
import ContainerAPIClient
import ContainerResource
import ContainerizationError
import Foundation

extension Application {
    public struct ContainerPrune: AsyncLoggableCommand {
        public init() {}

        public static let configuration = CommandConfiguration(
            commandName: "prune",
            abstract: "Remove all stopped containers"
        )

        @OptionGroup
        public var logOptions: Flags.Logging

        /// Deletes `ids` one by one and totals the space freed. A container whose deletion fails is
        /// reported through `onFailure`, and its size is not counted because it is still on disk.
        static func prune(
            ids: [String],
            diskUsage: (String) async throws -> UInt64,
            delete: (String) async throws -> Void,
            onFailure: (String, Error) -> Void
        ) async -> (pruned: [String], reclaimed: UInt64) {
            var pruned = [String]()
            var reclaimed: UInt64 = 0

            for id in ids {
                do {
                    let actualSize = try await diskUsage(id)
                    try await delete(id)
                    reclaimed += actualSize
                    pruned.append(id)
                } catch {
                    onFailure(id, error)
                }
            }
            return (pruned, reclaimed)
        }

        public func run() async throws {
            let client = ContainerClient()
            let filters = ContainerListFilters(status: .stopped).withoutPlugins([ResourcePluginValues.machine, ResourcePluginValues.cluster])
            let containersToPrune = try await client.list(filters: filters)

            let (prunedContainerIds, totalSize) = await Self.prune(
                ids: containersToPrune.map(\.id),
                diskUsage: { try await client.diskUsage(id: $0) },
                delete: { try await client.delete(id: $0) },
                onFailure: { id, error in
                    log.error(
                        "failed to prune container",
                        metadata: [
                            "id": "\(id)",
                            "error": "\(error)",
                        ])
                })

            let formatter = ByteCountFormatter()
            let freed = formatter.string(fromByteCount: Int64(totalSize))

            for name in prunedContainerIds {
                print(name)
            }
            log.info("Reclaimed \(freed) in disk space")
        }
    }
}
