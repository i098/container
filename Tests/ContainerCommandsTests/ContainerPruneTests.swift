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

import ContainerizationError
import Foundation
import Testing

@testable import ContainerCommands

struct ContainerPruneTests {
    @Test
    func failedDeletionIsNotCountedAsReclaimed() async {
        var failed: [String] = []

        let result = await Application.ContainerPrune.prune(
            ids: ["a", "stuck", "b"],
            diskUsage: { id in id == "stuck" ? 1_000_000 : 100 },
            delete: { id in
                if id == "stuck" {
                    throw ContainerizationError(.internalError, message: "cannot remove \(id)")
                }
            },
            onFailure: { id, _ in failed.append(id) }
        )

        #expect(result.pruned == ["a", "b"])
        #expect(result.reclaimed == 200)
        #expect(failed == ["stuck"])
    }
}
