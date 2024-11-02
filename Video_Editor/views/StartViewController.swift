//
//  StartViewController.swift
//  Video_Editor
//
//  Created by Yu Yang on 2024-11-01.
//

import UIKit
import AVFoundation
import SnapKit

struct ArchiveProject {
    let createDate: Date
    let modifyDate: Date
    let duration: CMTime
    let representImage: UIImage
    let sizeInMB: Float
}

class StartViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate {
    
    var tableView: UITableView!
    var headerView: UIButton!
    
    var headerViewHeightConstraint: ConstraintMakerEditable!
    var newProjectLabelRightConstraint: ConstraintMakerEditable!
    var headerViewTopConstraint: ConstraintMakerEditable!

    var titleLabel : UILabel!
    
    var archiveProjects: [ArchiveProject] = []
    
    // configuration
    let headerMinHeight: CGFloat = 30
    let headerMaxHeight: CGFloat = 70
    
    let tableViewContentInset: CGFloat = 100
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
        
        headerView = UIButton()
        headerView.backgroundColor = .red
        self.view.addSubview(headerView)
        setupHeaderView()
        
        headerView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(10)
            headerViewTopConstraint =  make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top).inset(headerTopInitialPadding)
            headerViewHeightConstraint = make.height.equalTo(headerMaxHeight)
        }

        tableView.showsVerticalScrollIndicator = false
        
        tableView.contentInset = UIEdgeInsets(top: tableViewContentInset, left: 0, bottom: 0, right: 0)
        tableView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(10)
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
        }

        prepareTestData()
        // fixed row height
        tableView.rowHeight = 100
        tableView.reloadData()
    }
    
    private func setupHeaderView() {
        headerView.layer.cornerRadius = 10
        headerView.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        
        let containerView = UIView()
        containerView.backgroundColor = .orange
        containerView.isUserInteractionEnabled = false
        headerView.addSubview(containerView)

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
            newProjectLabelRightConstraint = make.right.equalToSuperview().inset(0)
            make.centerY.equalToSuperview()
        }
        
        // contraint to the center
        containerView.snp.makeConstraints { make in
            make.center.equalTo(headerView)
            make.height.equalTo(addImageView.snp.height)
        }
    }
    
    @objc func addButtonTapped() {
        print("add button pressed")
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
        }
        
        let createTimeLabel : UILabel = cell.contentView.viewWithTag(100) as! UILabel
        let modifyTimeLabel : UILabel = cell.contentView.viewWithTag(101) as! UILabel
        let sizeDurationLabel : UILabel = cell.contentView.viewWithTag(102) as! UILabel
        let previewImgView : UIImageView = cell.contentView.viewWithTag(103) as! UIImageView
        
        let project = archiveProjects[indexPath.row]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMdd"
        createTimeLabel.text = dateFormatter.string(from: project.createDate)
        
        dateFormatter.dateFormat = "dd/MM/yyyy HH:mm"
        modifyTimeLabel.text = dateFormatter.string(from: project.modifyDate)
        
        let duration = Int(project.duration.seconds)
        let second = duration % 60
        let miniute = duration / 60
        sizeDurationLabel.text = "\(project.sizeInMB)MB    \(String(format: "%02d:%02d", miniute, second))"
        previewImgView.image = project.representImage
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return archiveProjects.count
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        var height = tableView.frame.height
        height -= headerMinHeight // header view minimal height
//        let itemsHeight = CGFloat(tableView.numberOfRows(inSection: section)) * tableView.size
        height -= (CGFloat(archiveProjects.count) * tableViewRowHeight)
        
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
        print("click at indexPath: \(indexPath)")
    }
    
    // MARK: - scrollview delegate
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let yOffset = scrollView.contentOffset.y
        
        if yOffset <= -tableViewContentInset {
            headerViewHeightConstraint.constraint.update(offset: headerMaxHeight)
            headerViewTopConstraint.constraint.update(offset: tableViewContentInset - headerMaxHeight)
            newProjectLabelRightConstraint.constraint.update(offset: -10)
            titleLabel.alpha = 1
        } else if yOffset <= -headerMinHeight {
            let progress = (tableViewContentInset + yOffset) / (tableViewContentInset - headerMinHeight)
            
            headerViewHeightConstraint.constraint.update(offset: max(headerMinHeight, headerMaxHeight - (headerMaxHeight - headerMinHeight) * progress))
            newProjectLabelRightConstraint.constraint.update(offset: progress * titleLabel.frame.width - 10)
            headerViewTopConstraint.constraint.update(offset: -yOffset - headerViewHeightConstraint.constraint.layoutConstraints.first!.constant)
            titleLabel.alpha = 1 - progress
        } else {
            headerViewHeightConstraint.constraint.update(offset: headerMinHeight)
            newProjectLabelRightConstraint.constraint.update(offset: titleLabel.frame.width - 10)
            headerViewTopConstraint.constraint.update(offset: 0)
            titleLabel.alpha = 0
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
    
    // MARK: - utility function
    private func scrollEndCheck(scrollView: UIScrollView) {
        let yOffset = scrollView.contentOffset.y
        if yOffset > -tableViewContentInset && yOffset < -headerMinHeight {
            // will either move up or move down
            let progress = (tableViewContentInset + yOffset) / (tableViewContentInset - headerMinHeight)
            if progress >= 0.5 {
               // move up
                headerViewHeightConstraint.constraint.update(offset: headerMinHeight)
                newProjectLabelRightConstraint.constraint.update(offset: titleLabel.frame.width)
                headerViewTopConstraint.constraint.update(offset: 0)
                UIView.animate(withDuration: 0.3) {
                    self.view.layoutIfNeeded()
                    self.tableView.setContentOffset(CGPoint(x: 0, y: -self.headerMinHeight), animated: false)
                }
            } else {
                // move down
                headerViewHeightConstraint.constraint.update(offset: headerMaxHeight)
                newProjectLabelRightConstraint.constraint.update(offset: -10)
                headerViewTopConstraint.constraint.update(offset: tableViewContentInset - headerMaxHeight)
                UIView.animate(withDuration: 0.3) {
                    self.view.layoutIfNeeded()
                    self.tableView.setContentOffset(CGPoint(x: 0, y: -self.tableViewContentInset), animated: false)
                }
            }
        }
    }
    
    // MARK: - prepare test data
    private func prepareTestData() {
        var images = [UIImage]()
        for i in 1...3 {
            let name = "pic_\(i)"
            let path = Bundle.main.path(forResource: name, ofType: "jpg")
            let data = try? Data(contentsOf: URL(fileURLWithPath: path!))
            images.append(UIImage(data: data!)!)
        }
        
        for image in images {
            let project = ArchiveProject(createDate: Date(), modifyDate: Date(), duration: CMTime(value: 10, timescale: 1), representImage: image, sizeInMB: 10)
            archiveProjects.append(project)
        }
    }
}


class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }


}

