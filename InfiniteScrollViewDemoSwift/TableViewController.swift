//
//  TableViewController.swift
//  InfiniteScrollViewDemoSwift
//
//  Created by pronebird on 5/3/15.
//  Copyright (c) 2015 pronebird. All rights reserved.
//

import UIKit
#if !os(tvOS)
import SafariServices
#endif

private let useAutosizingCells = true

class TableViewController: UITableViewController {
    fileprivate var currentPage = 0
    fileprivate var numPages = 0
    fileprivate var stories = [HackerNewsStory]()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        if useAutosizingCells, tableView.responds(to: #selector(getter: UIView.layoutMargins)) {
            tableView.estimatedRowHeight = 88
            tableView.rowHeight = UITableView.automaticDimension
        }

        // Set custom indicator
        let indicatorRect: CGRect
        #if os(tvOS)
        indicatorRect = CGRect(x: 0, y: 0, width: 64, height: 64)
        #else
        indicatorRect = CGRect(x: 0, y: 0, width: 24, height: 24)
        #endif
        tableView.infiniteScrollIndicatorView = CustomInfiniteIndicator(frame: indicatorRect)

        // Set custom indicator margin
        tableView.infiniteScrollIndicatorMargin = 40

        // Set custom trigger offset
        tableView.infiniteScrollTriggerOffset = 500

        // Add infinite scroll handler
        tableView.addInfiniteScroll { [weak self] tableView in
            self?.performFetch {
                tableView.finishInfiniteScroll()
            }
        }

        // Uncomment this to provide conditionally prevent the infinite scroll from triggering
        /*
         tableView.setShouldShowInfiniteScrollHandler { [weak self] (tableView) -> Bool in
             guard let self = self else { return false }

             // Only show up to 5 pages then prevent the infinite scroll
             return self.currentPage < 5
         }
         */

        // load initial data
        tableView.beginInfiniteScroll(true)
    }

    fileprivate func performFetch(_ completionHandler: (() -> Void)?) {
        fetchData { response, error in
            if let error = error {
                self.showAlertWithError(error)
            } else if let response = response {
                // create new index paths
                let storyCount = self.stories.count
                let (start, end) = (storyCount, response.hits.count + storyCount)
                let indexPaths = (start ..< end).map { IndexPath(row: $0, section: 0) }

                // update data source
                self.stories.append(contentsOf: response.hits)
                self.numPages = response.nbPages
                self.currentPage += 1

                // update table view
                self.tableView.beginUpdates()
                self.tableView.insertRows(at: indexPaths, with: .automatic)
                self.tableView.endUpdates()
            }

            completionHandler?()
        }
    }

    fileprivate func showAlertWithError(_ error: Error) {
        let alertController = UIAlertController(
            title: NSLocalizedString(
                "tableView.errorAlert.title",
                value: "Failed to fetch data",
                comment: ""
            ),
            message: error.localizedDescription,
            preferredStyle: .alert
        )

        alertController.addAction(UIAlertAction(
            title: NSLocalizedString("tableView.errorAlert.dismiss", value: "Dismiss", comment: ""),
            style: .cancel,
            handler: nil
        ))

        alertController.addAction(UIAlertAction(
            title: NSLocalizedString(
                "tableView.errorAlert.retry",
                value: "Retry",
                comment: ""
            ),
            style: .default,
            handler: { _ in self.performFetch(nil) }
        ))

        present(alertController, animated: true, completion: nil)
    }
}

// MARK: - Actions

extension TableViewController {
    @IBAction func handleRefresh() {
        tableView.beginInfiniteScroll(true)
    }
}

// MARK: - UITableViewDelegate

extension TableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let story = stories[indexPath.row]
        let url = story.url ?? story.postUrl

        #if !os(tvOS)
        let safariController = SFSafariViewController(url: url)
        safariController.delegate = self

        let safariNavigationController =
            UINavigationController(rootViewController: safariController)
        safariNavigationController.setNavigationBarHidden(true, animated: false)

        present(safariNavigationController, animated: true)
        #endif

        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension TableViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stories.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let story = stories[indexPath.row]

        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = story.title
        cell.detailTextLabel?.text = story.author

        if useAutosizingCells, tableView.responds(to: #selector(getter: UIView.layoutMargins)) {
            cell.textLabel?.numberOfLines = 0
            cell.detailTextLabel?.numberOfLines = 0
        }

        return cell
    }
}

// MARK: - SFSafariViewControllerDelegate

#if !os(tvOS)
extension TableViewController: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true)
    }
}
#endif

// MARK: - API

private extension TableViewController {
    func makeRequest(numHits: Int, page: Int) -> URLRequest {
        let url =
            URL(
                string: "https://hn.algolia.com/api/v1/search_by_date?tags=story&hitsPerPage=\(numHits)&page=\(page)"
            )!
        return URLRequest(url: url)
    }

    func fetchData(completion: @escaping ((HackerNewsResponse?, Error?) -> Void)) {
        let hits = Int(tableView.bounds.height) / 44
        let request = makeRequest(numHits: hits, page: currentPage)

        let task = URLSession.shared.dataTask(with: request, completionHandler: { data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }

                do {
                    let response = try JSONDecoder()
                        .decode(HackerNewsResponse.self, from: data ?? Data())

                    completion(response, nil)
                } catch {
                    completion(nil, error)
                }
            }
        })

        // I run task.resume() with delay because my network is too fast
        let delay = (stories.count == 0 ? 0 : 5)

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) {
            task.resume()
        }
    }
}
