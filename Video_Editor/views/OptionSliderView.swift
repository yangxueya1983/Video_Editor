//
//  OptionSliderView.swift
//  TimeLineVC
//
//  Created by Yu Yang on 2024-10-26.
//

import UIKit
import SnapKit

class OptionSliderView: UIView {
    var title: String?
    var subtitle: String?
    var options: [String]?
    var slider: UISlider!
    
    var selectIdxCB: ((Int, String) -> Void)?
    
    init(title: String, subtitle: String, options: [String], defaultOptIndx: Int) {
        super.init(frame: .zero)
        self.title = title
        self.subtitle = subtitle
        self.options = options
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        addSubview(titleLabel)
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.textColor = .gray
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        addSubview(subtitleLabel)
        
        slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = Float(options.count - 1)
        addSubview(slider)
        slider.value = Float(defaultOptIndx)

        titleLabel.snp.makeConstraints { make in
            make.left.top.equalToSuperview()
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.centerY.equalTo(titleLabel)
        }
        
        slider.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(5)
            make.left.equalToSuperview().offset(5)
            make.right.equalToSuperview().offset(-5)
        }
        
        let stackView = UIStackView(arrangedSubviews: options.map { opt in
            let label = UILabel()
            label.text = opt
            label.textColor = .gray
            label.font = .systemFont(ofSize: 13, weight: .medium)
            return label
        })
        
        stackView.axis = .horizontal
        stackView.distribution = .equalCentering
        addSubview(stackView)
        
        stackView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview().inset(5)
            make.top.equalTo(slider.snp.bottom).offset(5)
        }

        slider.addTarget(self, action: #selector (sliderTouchUp), for: .touchUpInside)
        
        // add tap gesture to the slider
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector (sliderTapped))
        slider.addGestureRecognizer(tapGesture)
    }
    
    @objc func sliderTouchUp(slider: UISlider) {
        let val = round(slider.value)
        slider.value = Float(val)
        
        let opt = options![Int(val)]
        selectIdxCB?(Int(val), opt)
    }
    
    @objc func sliderTapped(gesture: UITapGestureRecognizer) {
        guard let options = options, options.count >= 2 else {
            print("invalid options")
            return
        }
        
        let touchX = gesture.location(in: slider).x
        let sliderWidth = slider.frame.width
        
        let unitWidth = sliderWidth / CGFloat(options.count - 1)
        let selectIdx = round(touchX / unitWidth)
        guard selectIdx < CGFloat(options.count) else {
            return
        }
        
        slider.value = Float(selectIdx)
        selectIdxCB?(Int(selectIdx), options[Int(selectIdx)])
    }
    
    deinit {
        
    }
    
    required init?(coder: NSCoder) {
        // ignore this as we create the view from the code
        super.init(coder: coder)
        
    }
    
    
    
}
