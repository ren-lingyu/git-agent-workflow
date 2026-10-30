;;; release-notes.el -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'json)
(require 'org)
(require 'ox-gfm)
(require 'subr-x)
(require 'url)
(require 'url-http)
(require 'url-util)

(defconst release-notes-version-regexp
  "\\`v?[0-9]+\\.[0-9]+\\.[0-9]+\\(?:[-+][0-9A-Za-z.+-]+\\)?\\'")

(defun release-notes-env (name)
  "Return required environment variable NAME."
  (let ((value (getenv name)))
    (unless (and value (not (string-empty-p value)))
      (error "Missing environment variable: %s" name))
    value))

(defun release-notes-json (&rest entries)
  "Construct a JSON object from alternating key-value ENTRIES."
  (let ((object (make-hash-table :test #'equal)))
    (while entries
      (puthash (pop entries) (pop entries) object))
    object))

(defun release-notes-request (method path &optional payload)
  "Send a GitHub API request with METHOD, PATH and optional PAYLOAD."
  (let* ((url-request-method method)
         (url-request-extra-headers
          `(("Accept" . "application/vnd.github+json")
            ("Authorization" .
             ,(concat "Bearer " (release-notes-env "GITHUB_TOKEN")))
            ("X-GitHub-Api-Version" . "2022-11-28")
            ("Content-Type" . "application/json; charset=utf-8")))
         (url-request-data
          (when payload
            (json-serialize payload)))
         (url
          (concat
           "https://api.github.com/repos/"
           (release-notes-env "GITHUB_REPOSITORY")
           path))
         (response (url-retrieve-synchronously url t t 45)))
    (unless response
      (error "GitHub API request failed: %s %s" method path))
    (unwind-protect
        (with-current-buffer response
          (goto-char (point-min))
          (unless (looking-at "HTTP/[0-9.]+ \\([0-9]+\\)")
            (error "Invalid GitHub API HTTP response"))
          (let ((status (string-to-number (match-string 1))))
            (unless (re-search-forward "\r?\n\r?\n" nil t)
              (error "Missing GitHub API response body separator"))
            (let ((body
                   (buffer-substring-no-properties
                    (point) (point-max))))
              (unless (<= 200 status 299)
                (error "GitHub API %s %s: HTTP %d: %s"
                       method
                       path
                       status
                       body))
              (unless (string-empty-p body)
                (json-parse-string body
                                   :object-type 'hash-table
                                   :array-type 'list)))))
      (kill-buffer response))))

(defun release-notes-git-program ()
  "Return the Git executable to run."
  (or (getenv "GIT") "git"))

(defun release-notes-git (&rest arguments)
  "Run Git with ARGUMENTS and return its stdout."
  (with-temp-buffer
    (let* ((coding-system-for-read 'utf-8)
           (status
            (apply #'process-file
                   (release-notes-git-program)
                   nil
                   (current-buffer)
                   nil
                   arguments))
           (output (buffer-string)))
      (unless (equal status 0)
        (error "Git %s failed: %s"
               (car arguments)
               (string-trim output)))
      output)))

(defun release-notes-parse-command (subject)
  "Parse SUBJECT into (OPERATION . TAGS), or return nil."
  (cond
   ((string-match
     "\\`release(\\(create\\|update\\)): \\(.+\\)\\'" subject)
    (let* ((operation (intern (match-string 1 subject)))
           (argument (match-string 2 subject))
           (tags (split-string argument " " t)))
      (unless (string= argument (string-join tags " "))
        (error "Invalid spacing in release command"))
      (unless (cl-every
               (lambda (tag)
                 (string-match-p release-notes-version-regexp tag))
               tags)
        (error "Invalid release version: %s" argument))
      (unless (= (length tags)
                 (length (delete-dups (copy-sequence tags))))
        (error "Duplicate release versions"))
      (when (and (eq operation 'create) (/= (length tags) 1))
        (error "release(create) requires exactly one version"))
      (cons operation tags)))
   ((string-prefix-p "release(" subject)
    (error "Malformed release command: %s" subject))
   (t
    nil)))

(defun release-notes-verify-signature (sha)
  "Require GitHub to recognize SHA as a verified commit."
  (let* ((commit
          (release-notes-request
           "GET" (format "/git/commits/%s" sha)))
         (verification (gethash "verification" commit)))
    (unless (eq (gethash "verified" verification) t)
      (error "Unverified release command %s: %s"
             sha
             (gethash "reason" verification)))
    (message "GitHub verified commit %s" sha)))

(defun release-notes-require-tag (tag)
  "Require TAG to exist in the remote repository."
  (release-notes-git
   "ls-remote"
   "--exit-code"
   "--refs"
   "origin"
   (concat "refs/tags/" tag)))

(defun release-notes-fetch (ref)
  "Fetch REF and return its peeled commit SHA."
  (release-notes-git "fetch" "--no-tags" "--depth=1" "origin" ref)
  (string-trim (release-notes-git "rev-parse" "FETCH_HEAD^{commit}")))

(defun release-notes-read-file (sha path)
  "Read PATH directly from the Git commit SHA."
  (release-notes-git "show" (format "%s:%s" sha path)))

(defun release-notes-main-head ()
  "Resolve and freeze the remote default branch HEAD."
  (let* ((repository (release-notes-request "GET" ""))
         (branch (gethash "default_branch" repository))
         (sha (release-notes-fetch (concat "refs/heads/" branch))))
    (message "Release Notes source: %s at %s" branch sha)
    sha))

(defun release-notes-find-release (tag)
  "Find an existing GitHub Release, including drafts, by TAG."
  (catch 'found
    (let ((page 1))
      (while t
        (let ((releases
               (release-notes-request
                "GET"
                (format "/releases?per_page=100&page=%d" page))))
          (dolist (release releases)
            (when (equal (gethash "tag_name" release) tag)
              (throw 'found release)))
          (when (< (length releases) 100)
            (throw 'found nil)))
        (setq page (1+ page))))))

(defun release-notes-released-versions (source)
  "Extract ordered top-level DONE version names from Org SOURCE."
  (with-temp-buffer
    (insert source)
    (org-mode)
    (org-element-map
     (org-element-parse-buffer) 'headline
     (lambda (headline)
       (when (and (= (org-element-property :level headline) 1)
                  (equal
                   (org-element-property :todo-keyword headline)
                   "DONE"))
         (org-element-property :raw-value headline))))))

(defun release-notes-previous-tag (source tag)
  "Find the predecessor of TAG in the root Org changelog SOURCE."
  (let* ((versions (release-notes-released-versions source))
         (position (cl-position tag versions :test #'equal)))
    (unless position
      (error "No DONE entry for %s in CHANGELOG.org" tag))
    (unless (= (cl-count tag versions :test #'equal) 1)
      (error "Duplicate DONE entries for %s" tag))
    (nth (1+ position) versions)))

(defun release-notes-export (source)
  "Export Org SOURCE as a GitHub Markdown document body."
  (let ((org-export-use-babel nil)
        (org-export-with-title nil)
        (org-export-with-author nil)
        (org-export-with-date nil)
        (org-export-with-toc nil))
    (let ((markdown
           (string-trim
            (org-export-string-as
             source 'gfm t
             '(:with-title
               nil
               :with-author nil
               :with-date nil
               :with-toc nil)))))
      (when (string-empty-p markdown)
        (error "Org export produced empty Markdown"))
      markdown)))

(defun release-notes-body (tag previous manuscript)
  "Build release body for TAG from MANUSCRIPT and PREVIOUS."
  (let* ((repository (release-notes-env "GITHUB_REPOSITORY"))
         (base (concat "https://github.com/" repository))
         (source-url
          (format "%s/tree/%s" base (url-hexify-string tag)))
         (comparison
          (when previous
            (format "%s/compare/%s...%s"
                    base
                    (url-hexify-string previous)
                    (url-hexify-string tag)))))
    (concat
     (format "**Source**: %s\n\n" source-url)
     (if comparison
         (format "**Full Changelog**: %s\n\n" comparison)
       "")
     (release-notes-export manuscript) "\n")))

(defun release-notes-publish (operation tag main-sha)
  "Perform OPERATION on TAG, using MAIN-SHA for updates."
  (release-notes-require-tag tag)
  (let ((existing (release-notes-find-release tag)))
    (pcase operation
      ('create
       (when existing
         (error "Release %s already exists" tag)))
      ('update
       (unless existing
         (error "Release %s does not exist" tag))))

    (let* ((source-sha
            (if (eq operation 'create)
                (release-notes-fetch (concat "refs/tags/" tag))
              main-sha))
           (manuscript
            (release-notes-read-file
             source-sha (format "CHANGELOGS/%s.org" tag)))
           (changelog
            (release-notes-read-file source-sha "CHANGELOG.org"))
           (previous (release-notes-previous-tag changelog tag)))

      (when (string-empty-p (string-trim manuscript))
        (error "Empty Release Notes manuscript for %s" tag))
      (when previous
        (release-notes-require-tag previous))

      (let ((body (release-notes-body tag previous manuscript)))
        (pcase operation
          ('create
           (release-notes-request "POST" "/releases"
                                  (release-notes-json
                                   "tag_name"
                                   tag
                                   "name"
                                   tag
                                   "body"
                                   body
                                   "draft"
                                   :false "prerelease"
                                   :false
                                   "make_latest"
                                   "true")))
          ('update
           (release-notes-request
            "PATCH" (format "/releases/%s" (gethash "id" existing))
            (release-notes-json "body" body))))))

    (message "Succeeded: %s %s" operation tag)))

(defun release-notes-main ()
  "Execute the release command from the signed triggering commit."
  (let* ((sha (release-notes-env "GITHUB_SHA"))
         (checked-out
          (string-trim (release-notes-git "rev-parse" "HEAD")))
         (subject
          (string-trim-right
           (release-notes-git "log" "-1" "--format=%s" sha)))
         (command (release-notes-parse-command subject)))

    (unless (equal sha checked-out)
      (error "Checkout SHA does not match triggering commit"))

    (if (null command)
        (message "Not a release command: %s" subject)

      (release-notes-verify-signature sha)

      (let* ((operation (car command))
             (tags (cdr command))
             (main-sha
              (when (eq operation 'update)
                (release-notes-main-head)))
             (failures nil))

        (dolist (tag tags)
          (condition-case err
              (release-notes-publish operation tag main-sha)
            (error
             (let ((description
                    (format "%s: %s" tag (error-message-string err))))
               (message "Failed: %s" description)
               (push description failures)))))

        (when failures
          (error "Release operations failed: %s"
                 (string-join (nreverse failures) "; ")))))))

(provide 'release-notes)

;;; release-notes.el ends here
