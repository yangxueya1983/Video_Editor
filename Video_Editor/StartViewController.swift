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
    let duration: CMTime
}

class StartViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate {
    
    var tableView: UITableView!
    var headerView: UIButton!
    
    var headerViewHeightConstraint: ConstraintMakerEditable!
    var newProjectLabelRightConstraint: ConstraintMakerEditable!
    var headerViewTopConstraint: ConstraintMakerEditable!
    
//    var addIamgeViewLeftConstraint: NSLayoutConstraint!
    var titleLabel : UILabel!
    
    var archiveProjects: [ArchiveProject] = []
    
    // configuration
    let headerMinHeight: CGFloat = 30
    let headerMaxHeight: CGFloat = 70
    
    let tableViewContentInset: CGFloat = 100
    let tableViewRowHeight: CGFloat = 30
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
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        // add text
        titleLabel = UILabel()
        titleLabel.text = "New Project"
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .label
        containerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            newProjectLabelRightConstraint = make.left.equalTo(addImageView.snp.right).inset(-10)
            make.right.equalToSuperview().inset(0)
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

        if cell.contentView.viewWithTag(1) == nil {
            let durationLabel = UILabel()
            durationLabel.tag = 1
            durationLabel.textColor = .red
            durationLabel.textAlignment = .right
            cell.contentView.addSubview(durationLabel)
            durationLabel.frame = cell.contentView.frame
            durationLabel.translatesAutoresizingMaskIntoConstraints = false
        }
        
        let label : UILabel = cell.contentView.viewWithTag(1) as! UILabel
        label.text = archiveProjects[indexPath.row].createDate.timeIntervalSinceNow.description
        
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
//            heightConstraint.constant = headerMaxHeight
//            
//            headerView.snp.top.constant = tableViewContentInset - headerMaxHeight
//            headerViewTopConstraint.constant = tableViewContentInset - headerMaxHeight
            titleLabel.alpha = 1
        } else if yOffset <= -headerMinHeight {
            let progress = (tableViewContentInset + yOffset) / (tableViewContentInset - headerMinHeight)
//            heightConstraint.constant = max(headerMinHeight, headerMaxHeight - (headerMaxHeight - headerMinHeight) * progress)
            
            headerViewHeightConstraint.constraint.update(offset: max(headerMinHeight, headerMaxHeight - (headerMaxHeight - headerMinHeight) * progress))
            newProjectLabelRightConstraint.constraint.update(inset: progress * titleLabel.frame.width)
            headerViewTopConstraint.constraint.update(offset: -yOffset - headerViewHeightConstraint.constraint.layoutConstraints.first!.constant)
            
            
            titleLabel.alpha = 1 - progress
            
//            newProjectLabelRightConstraint.constant = progress * titleLabel.frame.width
//            headerViewTopConstraint.constant = -yOffset - heightConstraint.constant
        } else {
            headerViewHeightConstraint.constraint.update(offset: headerMinHeight)
            newProjectLabelRightConstraint.constraint.update(inset: titleLabel.frame.width)
            headerViewTopConstraint.constraint.update(offset: 0)
//            heightConstraint.constant = headerMinHeight
//            newProjectLabelRightConstraint.constant = titleLabel.frame.width
//            headerViewTopConstraint.constant = 0
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
//                self.heightConstraint.constant = self.headerMinHeight
//                self.newProjectLabelRightConstraint.constant = titleLabel.frame.width
//                self.headerViewTopConstraint.constant = 0
                UIView.animate(withDuration: 0.5) {
                    self.view.layoutIfNeeded()
                    self.tableView.setContentOffset(CGPoint(x: 0, y: -self.headerMinHeight), animated: false)
                }
            } else {
                // move down
//                self.heightConstraint.constant = self.headerMaxHeight
//                self.newProjectLabelRightConstraint.constant = -10
//                self.headerViewTopConstraint.constant = self.headerTopInitialPadding
                UIView.animate(withDuration: 0.5) {
                    self.view.layoutIfNeeded()
                    self.tableView.setContentOffset(CGPoint(x: 0, y: -self.tableViewContentInset), animated: false)
                }
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

