//
//  StartViewController.swift
//  Video_Editor
//
//  Created by Yu Yang on 2024-11-01.
//

import UIKit
import AVFoundation
import SnapKit
import Photos
import PhotosUI

struct ArchiveProject {
    let createDate: Date
    let modifyDate: Date
    let duration: CMTime
    let representImage: UIImage
    let sizeInMB: Float
}

class StartViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate, PHPickerViewControllerDelegate, UINavigationControllerDelegate {
    var tableView: UITableView!
    var newProjectBtn: UIButton!
    var headerView: UIView!
    
    var addProjBtnHeightCstr: ConstraintMakerEditable!
    var newProjLabelRightCstr: ConstraintMakerEditable!
    var addProjBtnTopCstr: ConstraintMakerEditable!
    var headerTopCstr: ConstraintMakerEditable!

    var titleLabel : UILabel!
    
    var previewProjects: [PreviewProject] = []
    
    // configuration
    let headerMinHeight: CGFloat = 30
    let headerMaxHeight: CGFloat = 120
    
    let tableViewContentInset: CGFloat = 150 // haderMinHeight + headerMaxHeight?
    let tableViewRowHeight: CGFloat = 100
    var headerTopInitialPadding: CGFloat { get {tableViewContentInset - headerMaxHeight} }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // add table view
        self.tableView = UITableView()
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        self.view.addSubview(tableView)
        
        headerView = UIView()
        self.view.addSubview(headerView)
        configureHeaderView()
        
        newProjectBtn = UIButton()
        newProjectBtn.backgroundColor = .systemCyan
        self.view.addSubview(newProjectBtn)
        configureAddProjectBtn()
        
        newProjectBtn.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(10)
            addProjBtnTopCstr =  make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top).inset(headerTopInitialPadding)
            addProjBtnHeightCstr = make.height.equalTo(headerMaxHeight)
        }

        tableView.showsVerticalScrollIndicator = false
        
        tableView.contentInset = UIEdgeInsets(top: tableViewContentInset, left: 0, bottom: 0, right: 0)
        tableView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(10)
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
        }

//        prepareTestData()
        // fixed row height
        tableView.rowHeight = 100
        tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.previewProjects = ProjectManager.sharedMgr.loadPreviewProjects()
        
        tableView.reloadData()
    }
    
    private func configureAddProjectBtn() {
        newProjectBtn.layer.cornerRadius = 10
        newProjectBtn.addTarget(self, action: #selector(newProjectButtonTapped), for: .touchUpInside)
        
        let containerView = UIView()
        containerView.isUserInteractionEnabled = false
        newProjectBtn.addSubview(containerView)

        // add New Project
        let addImageView = UIImageView(image: UIImage(systemName: "plus.app.fill"))
        addImageView.contentMode = .scaleAspectFit
        containerView.addSubview(addImageView)
        
        addImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(10)
            make.centerY.equalToSuperview()
        }
        
        // add text
        titleLabel = UILabel()
        titleLabel.text = "New Project"
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .label
        containerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(addImageView.snp.right).offset(10)
            newProjLabelRightCstr = make.right.equalToSuperview().inset(0)
            make.centerY.equalToSuperview()
        }
        
        // contraint to the center
        containerView.snp.makeConstraints { make in
            make.center.equalTo(newProjectBtn)
            make.height.equalTo(addImageView.snp.height)
        }
    }
    
    private func configureHeaderView() {
        headerView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(10)
            make.height.equalTo(headerMinHeight)
            headerTopCstr =  make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
        }
        
        // add icon
        let icon = UIImageView(image: UIImage(systemName: "wand.and.rays")?.withTintColor(.black, renderingMode: .alwaysOriginal))
        headerView.addSubview(icon)
        
        // add title
        let title = UILabel()
        title.text = "Video Edit"
        title.textColor = .label
        headerView.addSubview(title)
        
        // add setting btn
        let btn = UIButton()
        btn.setImage(UIImage(systemName: "gearshape")?.withTintColor(.black, renderingMode: .alwaysOriginal), for: .normal)
        btn.addTarget(self, action: #selector(settingBtnTapped), for: .touchUpInside)
        headerView.addSubview(btn)
        
        icon.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(10)
            make.centerY.equalToSuperview()
        }
        
        title.snp.makeConstraints { make in
            make.left.equalTo(icon.snp.right).offset(10)
            make.centerY.equalToSuperview()
        }
        
        btn.snp.makeConstraints { make in
            make.right.equalToSuperview().inset(10)
            make.centerY.equalToSuperview()
        }
    }
    
    // MARK: - table view datasource and delegate
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        if cell.contentView.subviews.count == 0 {
            let createTimeLabel = UILabel()
            createTimeLabel.tag = 100
            createTimeLabel.textColor = .label
            createTimeLabel.textAlignment = .left
            cell.contentView.addSubview(createTimeLabel)
            
            let modifyTimeLabel = UILabel()
            modifyTimeLabel.tag = 101
            modifyTimeLabel.textColor = .gray
            modifyTimeLabel.textAlignment = .left
            cell.contentView.addSubview(modifyTimeLabel)
            
            let sizeDurationLabel = UILabel()
            sizeDurationLabel.tag = 102
            sizeDurationLabel.textColor = .gray
            sizeDurationLabel.textAlignment = .left
            cell.contentView.addSubview(sizeDurationLabel)
            
            let previewImgView = UIImageView()
            previewImgView.tag = 103
            previewImgView.contentMode = .scaleAspectFill
            previewImgView.clipsToBounds = true
            previewImgView.layer.cornerRadius = 10
            cell.contentView.addSubview(previewImgView)
            
            let ellipseBtn = UIButton()
            ellipseBtn.tag = 104
            let ellipsisImage = UIImage(systemName: "ellipsis")?.withTintColor(.gray, renderingMode: .alwaysOriginal)
            ellipseBtn.setImage(ellipsisImage, for: .normal)
            ellipseBtn.addTarget(self, action: #selector(projectMoreSettingBtnTapped), for: .touchUpInside)
            cell.contentView.addSubview(ellipseBtn)
            
            // add constraints
            previewImgView.snp.makeConstraints { make in
                make.left.equalToSuperview().inset(10)
                make.width.height.equalTo(80)
                make.centerY.equalToSuperview()
            }
            
            modifyTimeLabel.snp.makeConstraints { make in
                make.left.equalTo(previewImgView.snp.right).offset(10)
                make.centerY.equalToSuperview()
            }
            
            createTimeLabel.snp.makeConstraints { make in
                make.left.equalTo(previewImgView.snp.right).offset(10)
                make.bottom.equalTo(modifyTimeLabel.snp.top).offset(-5)
            }
            
            sizeDurationLabel.snp.makeConstraints { make in
                make.left.equalTo(previewImgView.snp.right).offset(10)
                make.top.equalTo(modifyTimeLabel.snp.bottom).offset(5)
            }
            
            ellipseBtn.snp.makeConstraints { make in
                make.right.equalToSuperview().inset(10)
                make.centerY.equalToSuperview()
                make.height.width.equalTo(80)
            }
        }
        
        let createTimeLabel : UILabel = cell.contentView.viewWithTag(100) as! UILabel
        let modifyTimeLabel : UILabel = cell.contentView.viewWithTag(101) as! UILabel
        let sizeDurationLabel : UILabel = cell.contentView.viewWithTag(102) as! UILabel
        let previewImgView : UIImageView = cell.contentView.viewWithTag(103) as! UIImageView
        
        let project = previewProjects[indexPath.row]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMdd"
        createTimeLabel.text = dateFormatter.string(from: project._createDate)
        
        dateFormatter.dateFormat = "dd/MM/yyyy HH:mm"
        modifyTimeLabel.text = dateFormatter.string(from: project._modifyDate)
        
        let duration = Int(project._videoDuration)
        let second = duration % 60
        let miniute = duration / 60
        var size = project._videoEstimateSize
        var sizeUnit = "Bytes"
        if size > 1024 {
            size /= 1024
            sizeUnit = "KB"
        }
        if size > 1024 {
            size /= 1024
            sizeUnit = "MB"
        }
        
        sizeDurationLabel.text = "\(size)\(sizeUnit)    \(String(format: "%02d:%02d", miniute, second))"
        previewImgView.image = project._thumnail
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return previewProjects.count
    }
    
    func tableView(_ tableView123: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        var height = tableView.frame.height
        height -= headerMinHeight // header view minimal height
//        let itemsHeight = CGFloat(tableView.numberOfRows(inSection: section)) * tableView.size
        height -= (CGFloat(previewProjects.count) * tableViewRowHeight)
        
        return max(height, 0)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableViewRowHeight
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footerView = UIView()
        footerView.backgroundColor = .clear
        footerView.isUserInteractionEnabled = false
        return footerView
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // present the editor view
        let editorVC = EditViewController()
        editorVC.modalPresentationStyle = .fullScreen
        
        let previewProject = previewProjects[indexPath.row]
        editorVC.project = previewProject.getArchivedProject()
        
        present(editorVC, animated: true)
    }
    
    // MARK: - scrollview delegate
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let yOffset = scrollView.contentOffset.y
        
        if yOffset <= -tableViewContentInset {
            // max height
            addProjBtnHeightCstr.constraint.update(offset: headerMaxHeight)
            addProjBtnTopCstr.constraint.update(offset: tableViewContentInset - headerMaxHeight)
            newProjLabelRightCstr.constraint.update(offset: -10)
            titleLabel.alpha = 1
            headerView.alpha = 1
        } else if yOffset <= -headerMinHeight {
            // between min height and max height
            let progress = (tableViewContentInset + yOffset) / (tableViewContentInset - headerMinHeight)
            
            addProjBtnHeightCstr.constraint.update(offset: max(headerMinHeight, headerMaxHeight - (headerMaxHeight - headerMinHeight) * progress))
            newProjLabelRightCstr.constraint.update(offset: progress * titleLabel.frame.width - 10)
            addProjBtnTopCstr.constraint.update(offset: -yOffset - addProjBtnHeightCstr.constraint.layoutConstraints.first!.constant)
            titleLabel.alpha = 1 - progress
            
            // header view alpha is 0 when the progress is 25% or larger
            let headerViewProgress = min(1.0, progress * 4)
            headerView.alpha = 1 - headerViewProgress
            
            headerTopCstr.constraint.update(offset: -headerViewProgress * 20)
        } else {
            // min height
            addProjBtnHeightCstr.constraint.update(offset: headerMinHeight)
            newProjLabelRightCstr.constraint.update(offset: titleLabel.frame.width - 10)
            addProjBtnTopCstr.constraint.update(offset: 0)
            titleLabel.alpha = 0
            
            headerView.alpha = 0
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollEndCheck(scrollView: scrollView)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate {
            return
        }
        
        scrollEndCheck(scrollView: scrollView)
    }
    
    // MARK: - event handling
    @objc private func newProjectButtonTapped() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        picker.modalPresentationStyle = .fullScreen
        present(picker, animated: true)
    }
    
    @objc private func projectMoreSettingBtnTapped(_ btn: UIButton) {
        // find the index path
        if let cell = btn.superview?.superview as? UITableViewCell, let indexPath = tableView.indexPath(for: cell) {
            print("indexPath: \(indexPath)")
        }
    }
    
    @objc private func settingBtnTapped(_ btn: UIButton) {
        print("setting button pressed")
    }
    
    // MARK: - utility function
    private func scrollEndCheck(scrollView: UIScrollView) {
        let yOffset = scrollView.contentOffset.y
        if yOffset > -tableViewContentInset && yOffset < -headerMinHeight {
            // will either move up or move down
            let progress = (tableViewContentInset + yOffset) / (tableViewContentInset - headerMinHeight)
            if progress >= 0.5 {
               // move up
                addProjBtnHeightCstr.constraint.update(offset: headerMinHeight)
                // should be the same as in the did scroll counterpart
                newProjLabelRightCstr.constraint.update(offset: titleLabel.frame.width - 10)
                addProjBtnTopCstr.constraint.update(offset: 0)
                UIView.animate(withDuration: 0.3) {
                    self.view.layoutIfNeeded()
                    self.tableView.setContentOffset(CGPoint(x: 0, y: -self.headerMinHeight), animated: false)
                }
            } else {
                // move down
                addProjBtnHeightCstr.constraint.update(offset: headerMaxHeight)
                newProjLabelRightCstr.constraint.update(offset: -10)
                addProjBtnTopCstr.constraint.update(offset: tableViewContentInset - headerMaxHeight)
                
                headerTopCstr.constraint.update(offset: 0)
                UIView.animate(withDuration: 0.3) {
                    self.view.layoutIfNeeded()
                    self.tableView.setContentOffset(CGPoint(x: 0, y: -self.tableViewContentInset), animated: false)
                    self.headerView.alpha = 1
                }
            }
        }
    }

    
    // MARK - PHPhotolibrary view controller delegate
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        // load the original images
        if results.isEmpty {
            picker.dismiss(animated: true)
            return
        }
        
        var images: [UIImage?] = Array(repeating: nil, count: results.count)
        
        // let the heavy job done here
        
        Task {
            do {
                try await withThrowingTaskGroup(of: (Int, UIImage?).self, body: { group in
                    for (index, result) in results.enumerated() {
                        group.addTask {
                            let image  = try await self.loadImage(from: result)
                            return (index, image)
                        }
                    }
                    
                    for try await (idx, result) in group {
                        images[idx] = result
                    }
                })
            } catch {
                printContent("Error loading images: \(error)")
            }
            
            guard images.allSatisfy({$0 != nil}) else {
                DispatchQueue.main.async {
                    print("load images failed")
                    picker.dismiss(animated: true)
                }
                return
            }
            
            // TODO: create projects from the images
            guard let projPath = ProjectManager.sharedMgr.getNextProjectDir() else {
                print("could not get the next project directory")
                picker.dismiss(animated: true)
                return
            }
            
            let project = EditProject(dir: projPath)
            
            for image in images {
                guard let image, let assetDir = project.getNextAssetDirectory() else { continue }
                let photoAsset = PhotoEditAsset(image: image, cacheDir: assetDir)
                if !project.addVisualAsset(photoAsset) {
                    assert(false)
                }
            }
            
            DispatchQueue.main.async {
                picker.dismiss(animated: false) {
                    let editorVC = EditViewController()
                    editorVC.project = project
                    editorVC.modalPresentationStyle = .fullScreen
                    self.present(editorVC, animated: true)
                }
            }
        }
    }
    
    // Async function to load a single image from PHPickerResult
    private func loadImage(from result: PHPickerResult) async throws -> UIImage? {
        try await withCheckedThrowingContinuation { continuation in
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let image = object as? UIImage {
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            } else {
                continuation.resume(returning: nil)
            }
        }
    }
}


class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }


}

