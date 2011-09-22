/**************************************************************************
 *    Butaca
 *    Copyright (C) 2011 Simon Pena <spena@igalia.com>
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 **************************************************************************/

import QtQuick 1.1
import com.nokia.meego 1.0
import com.nokia.extras 1.0
import "file:///usr/lib/qt4/imports/com/meego/UIConstants.js" as UIConstants
import "butacautils.js" as BUTACA
import "storage.js" as Storage

Page {
    tools: commonTools
    orientationLock: PageOrientation.LockPortrait

    property alias searchTerm: searchInput.text
    property string location
    property variant currentListView: movieResultsList

    function handleTheatersFetched(ok) {
        if (searchResults.state == 'AbstractModelSearch') {
            searchResults.state = 'SearchFinished'
        }
    }

    onStatusChanged: {
        if (status == PageStatus.Active) {
            Storage.initialize()
            location = Storage.getSetting('location')
        } else if (status == PageStatus.Activating) {
            if (searchCategory.checkedButton == showSearch) {
                theaterModel.setFilterWildcard(searchInput.text)
            }
        }
    }

    Connections {
        target: controller
        onTheatersFetched: handleTheatersFetched(ok)
    }

    ButacaHeader {
        anchors.top: parent.top
        anchors.topMargin: appWindow.inPortrait?
                               UIConstants.HEADER_DEFAULT_TOP_SPACING_PORTRAIT :
                               UIConstants.HEADER_DEFAULT_TOP_SPACING_LANDSCAPE
        id: header
        text: 'Search'
    }

    Row {
        id: searchArea
        anchors { top: header.bottom; left: parent.left; right: parent.right }
        anchors.margins: UIConstants.DEFAULT_MARGIN
        spacing: 10

        TextField {
            id: searchInput
            placeholderText: "Enter search terms"
            width: parent.width - searchButton.width - 10
//                onAccepted: {
//                    searchButton.clicked()
//                }

            Image {
                id: clearText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                source: searchInput.activeFocus ?
                            'image://theme/icon-m-input-clear' :
                            'image://theme/icon-m-common-search'
            }

            MouseArea {
                id: searchInputMouseArea
                anchors.fill: clearText
                onClicked: {
                    inputContext.reset()
                    searchInput.text = ''
                    searchResults.state = 'Waiting'
                }
            }
        }

        Button {
            id: searchButton
            text: 'Search'
            width: 100
            enabled: searchInput.text !== ''
            onClicked: {
                if (searchCategory.checkedButton == movieSearch) {
                    searchResults.state = 'XmlModelSearch'
                } else if (searchCategory.checkedButton == peopleSearch) {
                    searchResults.state = 'XmlModelSearch'
                } else {
                    theaterModel.setFilterWildcard(searchInput.text)
                    if (theaterModel.count === 0 ||
                            location != controller.currentLocation()) {
                        controller.fetchTheaters(location)
                        searchResults.state = 'AbstractModelSearch'
                    } else {
                        currentListView.visible = true
                        searchResults.state = 'SearchFinished'
                    }
                }
            }
        }
    }

    ButtonRow {
        id: searchCategory
        anchors { top: searchArea.bottom; left: parent.left; right: parent.right }
        anchors.margins: UIConstants.DEFAULT_MARGIN

        Button {
            id: movieSearch
            text: 'Movies'
            onClicked: {
                if (currentListView != movieResultsList) {
                    currentListView = movieResultsList
                    searchResults.state = 'Waiting'
                }
            }
        }
        Button {
            id: peopleSearch
            text: 'People'
            onClicked: {
                if (currentListView != peopleResultsList) {
                    currentListView = peopleResultsList
                    searchResults.state = 'Waiting'
                }
            }
        }
        Button {
            id: showSearch
            text: 'Shows'
            onClicked: {
                if (currentListView != showtimesResultsList) {
                    currentListView = showtimesResultsList
                    searchResults.state = 'Waiting'
                }
            }
        }
    }

    Item {
        id: searchResults
        anchors {
            top: searchCategory.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        anchors.topMargin: UIConstants.DEFAULT_MARGIN
        state: 'Waiting'

        ListView {
            id: peopleResultsList
            anchors.fill: parent
            clip: true
            flickableDirection: Flickable.VerticalFlick
            model: PeopleModel {
                id: peopleModel
                source: ''
                onStatusChanged: {
                    if (status == XmlListModel.Ready &&
                            searchResults.state == 'XmlModelSearch') {
                        searchResults.state = 'SearchFinished'
                    }
                }
            }
            delegate: CustomListDelegate {
                onClicked: { pageStack.push(personView,
                                            { detailId: personId,
                                              viewType: BUTACA.PERSON })}
            }
            visible: false
        }

        ListView {
            id: movieResultsList
            anchors.fill: parent
            clip: true
            flickableDirection: Flickable.VerticalFlick
            model: MultipleMoviesModel {
                id: moviesModel
                source: ''
                onStatusChanged: {
                    if (status == XmlListModel.Ready &&
                            searchResults.state == 'XmlModelSearch') {
                        searchResults.state = 'SearchFinished'
                    }
                }
            }
            delegate: MultipleMoviesDelegate {
                onClicked: {
                    pageStack.push(movieView,
                                   { detailId: tmdbId,
                                     viewType: BUTACA.MOVIE })
                }
            }
            visible: false
        }

        ListView {
            id: showtimesResultsList
            anchors.fill: parent
            clip: true
            flickableDirection: Flickable.VerticalFlick
            model: theaterModel
            delegate: CustomListDelegate {
                pressable: false
            }
            section.delegate: ListSectionDelegate { sectionName: section }
            section.property: 'theaterName'
            visible: false
        }

        NoContentItem {
            id: noResults
            anchors.fill: parent
            visible: false
        }

        BusyIndicator {
            id: busyIndicator
            visible: false
            platformStyle: BusyIndicatorStyle { size: 'large' }
            anchors.centerIn: parent
        }

        ScrollDecorator {
            id: scrollDecorator
            flickableItem: currentListView
        }

        states: [
            State {
                name: 'Waiting'
                when: searchInput.activeFocus
                PropertyChanges { target: showtimesResultsList; restoreEntryValues: false; visible: false }
                PropertyChanges { target: peopleResultsList; restoreEntryValues: false; visible: false }
                PropertyChanges { target: movieResultsList; restoreEntryValues: false; visible: false }
                PropertyChanges { target: moviesModel; restoreEntryValues: false; source: '' }
                PropertyChanges { target: peopleModel; restoreEntryValues: false; source: '' }
                PropertyChanges { target: noResults; restoreEntryValues: false; visible: false }
                PropertyChanges { target: busyIndicator; restoreEntryValues: false; visible: false; running: false }
            },
            State {
                name: 'XmlModelSearch'
                PropertyChanges {
                    target: currentListView.model
                    restoreEntryValues: false
                    source: currentListView.model === moviesModel ?
                                BUTACA.getTMDbSource(BUTACA.TMDB_MOVIE_SEARCH, searchTerm) :
                                BUTACA.getTMDbSource(BUTACA.TMDB_PERSON_SEARCH, searchTerm)
                }
                PropertyChanges  {
                    target: currentListView
                    restoreEntryValues: false
                    visible: true
                }
                PropertyChanges { target: busyIndicator; visible: true; running: true }
            },
            State {
                name: 'AbstractModelSearch'
                PropertyChanges  {
                    target: showtimesResultsList
                    restoreEntryValues: false;
                    visible: true
                }
                PropertyChanges { target: busyIndicator; visible: true; running: true }
            },
            State {
                name: 'SearchFinished'
                PropertyChanges {
                    target: noResults
                    visible: currentListView ? currentListView.model.count === 0 : false
                    text: 'No results found'
                }
                PropertyChanges {
                    target: busyIndicator
                    visible: false
                    running: false
                }
            }
        ]
    }
}