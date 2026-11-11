import Foundation

// The step-by-step preview (docs/api.md, "POST /v1/preview/stream"): one
// JSON object per line. Foundation only.

/// One check the server reports on. `label` is the server's text, ready to
/// display; it changes between `active` and `done`.
struct PreviewStep: Equatable, Identifiable {
    enum State: String, Equatable {
        case active, done
    }

    let id: String
    var state: State
    var label: String
}

/// What the client reports while a link is being checked.
enum PreviewEvent: Equatable {
    case step(PreviewStep)
    /// A site the link passes through, as it is reached.
    case hop(host: String)
    /// The server has no step-by-step endpoint: the plain one is being used
    /// and nothing more is reported until the result.
    case withoutSteps
    /// Always the last event.
    case result(PreviewResult)
}

/// One line of the stream.
enum PreviewStreamLine: Equatable {
    case event(PreviewEvent)
    /// An `error` line: the check ended without a result.
    case failure(PreviewFailure)

    private struct Kind: Decodable {
        let type: String?
    }

    private struct StepLine: Decodable {
        let id: String?
        let state: String?
        let label: String?
    }

    private struct HopLine: Decodable {
        struct Detail: Decodable {
            let host: String?
        }
        let hop: Detail?
    }

    private struct ResultLine: Decodable {
        let result: PreviewResult
    }

    private struct ErrorLine: Decodable {
        struct Detail: Decodable {
            let code: String?
            let message: String?
        }
        let status: Int?
        let error: Detail?
    }

    /// Reads one line. Nil for anything that is not understood: blank or
    /// broken lines, unknown event types, steps in an unknown state.
    static func parse(_ line: String) -> PreviewStreamLine? {
        let data = Data(line.utf8)
        let decoder = JSONDecoder()
        guard let kind = try? decoder.decode(Kind.self, from: data), let type = kind.type else {
            return nil
        }

        switch type {
        case "step":
            guard let step = try? decoder.decode(StepLine.self, from: data),
                  let id = step.id, !id.isEmpty,
                  let state = PreviewStep.State(rawValue: step.state ?? "") else {
                return nil
            }
            return .event(.step(PreviewStep(id: id, state: state, label: step.label ?? "")))
        case "hop":
            guard let host = (try? decoder.decode(HopLine.self, from: data))?.hop?.host, !host.isEmpty else {
                return nil
            }
            return .event(.hop(host: host))
        case "result":
            guard let decoded = try? decoder.decode(ResultLine.self, from: data) else {
                // A result that cannot be read is the end all the same.
                return .failure(.unexpected)
            }
            return .event(.result(decoded.result))
        case "error":
            let decoded = try? decoder.decode(ErrorLine.self, from: data)
            let code = decoded?.error?.code ?? PreviewDecoding.fallbackCode(forStatus: decoded?.status ?? 500)
            return .failure(.server(code: code, message: decoded?.error?.message ?? ""))
        default:
            return nil
        }
    }
}

/// The checklist on the checking screen: steps in the order they first
/// arrived, and the sites passed through so far.
struct PreviewProgress: Equatable {
    /// The step under which the sites are listed.
    static let redirectsStepID = "redirects"

    private(set) var steps: [PreviewStep] = []
    private(set) var hosts: [String] = []

    var isEmpty: Bool {
        return steps.isEmpty
    }

    mutating func apply(_ event: PreviewEvent) {
        switch event {
        case .step(let step):
            if let index = steps.firstIndex(where: { $0.id == step.id }) {
                steps[index].state = step.state
                if !step.label.isEmpty {
                    steps[index].label = step.label
                }
            } else if !step.label.isEmpty {
                steps.append(step)
            }
        case .hop(let host):
            if !host.isEmpty && host != hosts.last {
                hosts.append(host)
            }
        case .withoutSteps, .result:
            break
        }
    }
}
