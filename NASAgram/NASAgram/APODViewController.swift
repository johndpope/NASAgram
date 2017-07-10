//
//  APODViewController.swift
//  NASAgram
//
//  Created by Tom Seymour on 6/27/17.
//  Copyright © 2017 seymotom. All rights reserved.
//

import UIKit
import SnapKit

protocol APODViewDelegate {
    func toggleFavorite()
    func toggleTabBar()
}

class APODViewController: UIViewController, UIGestureRecognizerDelegate {
    
    let date: Date!
    
    var apod: APOD? {
        return DataManager.shared.apod(for: date.yyyyMMdd())
    }
    
    let apodImageView = APODImageView()
    let apodInfoView = APODInfoView()
    
    init(date: Date, dateDelegate: APODDateDelegate) {
        self.date = date
        self.apodInfoView.dateDelegate = dateDelegate
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupConstraints()
        setupGestures()
        getAPOD()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        toggleTabBar()
        
        // reset the favorites star if deleted from favorites
        if let apod = apod {
            apodInfoView.populateInfo(from: apod)
        }
    }
    
    
    func setupView() {
        view.backgroundColor = .black
        view.addSubview(apodImageView)
        
        view.addSubview(apodInfoView)
        apodInfoView.isHidden = true
        apodInfoView.viewDelegate = self
    }
    
    func setupConstraints() {
        apodImageView.snp.makeConstraints { (view) in
            view.leading.trailing.bottom.equalToSuperview()
            view.top.equalTo(topLayoutGuide.snp.bottom)
        }
        
        apodInfoView.snp.makeConstraints { (view) in
            view.leading.trailing.equalToSuperview()
            view.top.equalTo(topLayoutGuide.snp.bottom)
            view.bottom.equalTo(bottomLayoutGuide.snp.top)
        }
    }
    
    func setupGestures() {
        var recognizers = [UIGestureRecognizer]()
        
        let tapRecognizer = UITapGestureRecognizer()
        tapRecognizer.numberOfTapsRequired = 1
        recognizers.append(tapRecognizer)
        
        let doubleTapRecognizer = UITapGestureRecognizer()
        doubleTapRecognizer.numberOfTapsRequired = 2
        tapRecognizer.require(toFail: doubleTapRecognizer)
        recognizers.append(doubleTapRecognizer)
        
        recognizers.forEach { (recognizer) in
            recognizer.delegate = self
            recognizer.addTarget(self, action: #selector(handleGesture(sender:)))
            recognizer.cancelsTouchesInView = false
            view.addGestureRecognizer(recognizer)
        }
    }
    
    func getAPOD() {
        // checks favorites before hitting api
        FavoritesManager.shared.fetchAPOD(date: date.yyyyMMdd()) { (apod) in
            if let apod = apod {
                DispatchQueue.main.async {
                    self.apodInfoView.populateInfo(from: apod)
                    self.apodImageView.image = UIImage(data: apod.hdImageData! as Data)
                }
            } else {
                self.loadAPOD()
            }
        }
    }
    
    func loadAPOD() {
        DataManager.shared.getAPOD(from: date) { (apod) in
            DispatchQueue.main.async {
                self.apodInfoView.populateInfo(from: apod)
            }
            switch apod.mediaType {
            case .image:
                if let hdurl = apod.hdurl {
                    DataManager.shared.getImage(url: hdurl, completion: { (data) in
                        DispatchQueue.main.async {
                            self.apod?.hdImageData = data as NSData
                            let image = UIImage(data: data)
                            self.apod?.ldImageData = UIImageJPEGRepresentation(image!, 0.25)! as NSData
                            self.apodImageView.image = image
                        }
                    })
                }
            case .video:
                print("Video")
                self.apodImageView.image = #imageLiteral(resourceName: "Video-Icon")
            }
        }
    }
    
    func handleGesture(sender: UITapGestureRecognizer) {
        if apodInfoView.isHidden {
            switch sender.numberOfTapsRequired {
            case 1:
                // apodInfoView.isHidden = apodInfoView.isHidden ? false : true
                apodInfoView.isHidden = false
                toggleTabBar()
            case 2 where apodInfoView.isHidden:
                apodImageView.doubleTapZoom(for: sender)
            default:
                break
            }
        }
        
    }
    
    // MARK:- Rotation
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { (context) in
            self.apodImageView.rotate()
        }) { (context) in
        }
    }
}

extension APODViewController: APODViewDelegate {
    
    func toggleTabBar() {
        tabBarController?.tabBar.isHidden = apodInfoView.isHidden ? true : false
    }
    
    func toggleFavorite() {
        
        guard let apod = apod else { return }
        
        // DRY
        
        if apod.isFavorite {
            FavoritesManager.shared.delete(apod) { (success) in
                print("delete was \(success)")
                if success {
                    apod.isFavorite = false
                    DispatchQueue.main.async {
                        self.apodInfoView.populateInfo(from: apod)
                    }                    
                }
            }
        } else {
            FavoritesManager.shared.save(apod) { (success, error) in
                print("save was \(success)")
                if success {
                    apod.isFavorite = true
                    DispatchQueue.main.async {
                        self.apodInfoView.populateInfo(from: apod)
                    }
                }
            }
        }
    }
}



