//
//  TestPageVC.swift
//  Video_Editor
//
//  Created by Yu Yang on 2024-12-14.
//

import UIKit
import PagingKit
import SnapKit

protocol TransitionGrouopCollectionVCDelegate {
    func selectTransitionIndex(_ grpIdx: Int, _ itemIndex: Int)
}

class TransitionGroupCollectionVC : UICollectionViewController {
    private let reuseIdentifier = "MyCell"
    
    var transitionNames: [String] = []
    var groupIdx = 0
    
    var delegate : TransitionGrouopCollectionVCDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.contentInset = UIEdgeInsets(top: 20, left: 10, bottom: 20, right: 10)
        // Register the cell class or nib
        self.collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return transitionNames.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
        cell.backgroundColor = .systemBlue // Customize cell appearance
        
        if cell.contentView.viewWithTag(1) == nil {
            // add label
            let label = UILabel()
            label.tag = 1
            label.textAlignment = .center
            label.textColor = .white
            label.font = UIFont.systemFont(ofSize: 12)
            cell.contentView.addSubview(label)
            label.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
        }
        
        let label = cell.contentView.viewWithTag(1) as! UILabel
        label.text = transitionNames[indexPath.item]
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.selectTransitionIndex(groupIdx, indexPath.item)
    }
    
}

class TransitionTypeMenuVC: UIViewController {
    var menuViewController : PagingMenuViewController = PagingMenuViewController()
    var contentViewController: PagingContentViewController = PagingContentViewController()
    
    static var sizingCell = TitleLabelMenuViewCell(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    
    let menus = ["Basic"]
    // group transition types and group transition type names should match
    let groupTransitionTypes = [[TransitionType.None, TransitionType.MoveLeft, TransitionType.MoveUp, TransitionType.MoveRight, TransitionType.MoveDown]]
    let groupTransitionTypeNames = [["None", "Move Left", "Move Up", "Move Right", "Move Down"]]
    
    var dataSource = [(menu: String, content: UIViewController)]() {
        didSet {
            menuViewController.reloadData()
            contentViewController.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addChild(menuViewController)
        addChild(contentViewController)
        
        self.view.addSubview(menuViewController.view)
        self.view.addSubview(contentViewController.view)
        
        menuViewController.view.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(self.view.snp.topMargin)
            make.height.equalTo(50)
        }
        
        contentViewController.view.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalTo(self.view.snp.bottomMargin)
            make.top.equalTo(menuViewController.view.snp.bottom)
        }
        
        menuViewController.register(type: TitleLabelMenuViewCell.self, forCellWithReuseIdentifier: "identifier")
        menuViewController.registerFocusView(view: UnderlineFocusView())
        
        menuViewController.dataSource = self
        menuViewController.delegate = self
        contentViewController.dataSource = self
        contentViewController.delegate = self
        
        dataSource = makeDataSource(menus: menus)
    }
    
    func makeDataSource(menus: [String]) -> [(menu: String, content: UIViewController)] {
        return menus.enumerated().map { (index, element) in
            let title = element
            
            // Set up the flow layout
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .vertical // Scrolling direction
            layout.itemSize = CGSize(width: 80, height: 80) // Item size
            layout.minimumLineSpacing = 20 // Spacing between rows
            layout.minimumInteritemSpacing = 10 // Spacing between columns
            
            let vc = TransitionGroupCollectionVC(collectionViewLayout: layout)
            vc.transitionNames = groupTransitionTypeNames[index]
            vc.groupIdx = index
            vc.delegate = self
            
            vc.view.backgroundColor = .yellow
            return (menu: title, content: vc)
        }
    }
}

extension TransitionTypeMenuVC : TransitionGrouopCollectionVCDelegate {
    func selectTransitionIndex(_ grpIdx: Int, _ itemIndex: Int) {
        
    }
}

extension TransitionTypeMenuVC: PagingMenuViewControllerDataSource {
    func menuViewController(viewController: PagingMenuViewController, cellForItemAt index: Int) -> PagingMenuViewCell {
        let cell = viewController.dequeueReusableCell(withReuseIdentifier: "identifier", for: index)  as! TitleLabelMenuViewCell
        cell.titleLabel.text = dataSource[index].menu
        return cell
    }
    
    func menuViewController(viewController: PagingMenuViewController, widthForItemAt index: Int) -> CGFloat {
        TransitionTypeMenuVC.sizingCell.titleLabel.text = dataSource[index].menu
        var referenceSize = UIView.layoutFittingCompressedSize
        referenceSize.height = viewController.view.bounds.height
        let size = TransitionTypeMenuVC.sizingCell.systemLayoutSizeFitting(referenceSize)
        return size.width
    }
    
    
    func numberOfItemsForMenuViewController(viewController: PagingMenuViewController) -> Int {
        return dataSource.count
    }
}

extension TransitionTypeMenuVC: PagingContentViewControllerDataSource {
    func numberOfItemsForContentViewController(viewController: PagingContentViewController) -> Int {
        return dataSource.count
    }
    
    func contentViewController(viewController: PagingContentViewController, viewControllerAt index: Int) -> UIViewController {
        return dataSource[index].content
    }
}

extension TransitionTypeMenuVC: PagingMenuViewControllerDelegate {
    func menuViewController(viewController: PagingMenuViewController, didSelect page: Int, previousPage: Int) {
        contentViewController.scroll(to: page, animated: true)
    }
}

extension TransitionTypeMenuVC: PagingContentViewControllerDelegate {
    func contentViewController(viewController: PagingContentViewController, didManualScrollOn index: Int, percent: CGFloat) {
        menuViewController.scroll(index: index, percent: percent, animated: false)
    }
}
